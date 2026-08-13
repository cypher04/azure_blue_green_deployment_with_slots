# Azure Blue-Green Deployment with App Service Slots

Terraform infrastructure for a blue-green deployment on Azure App Service, plus the Node.js application that runs on it. The production web app carries two deployment slots — blue (`staging`) and green (`staging2`) — and Terraform declares which slot is active. Traffic reaches the platform through Azure Traffic Manager and through an Application Gateway with a WAF policy in front of a static public IP.

## Contents

| Path | Purpose |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Resource-by-resource description of the deployed infrastructure |
| [TRAFFIC_FLOW.md](TRAFFIC_FLOW.md) | How a request travels from DNS to the database, and how the slots swap |
| [backend/](backend/) | Storage Account and container that hold the remote Terraform state |
| [env/dev/](env/dev/) | The root module that is wired up and deployable |
| [env/stage/](env/stage/), [env/prod/](env/prod/) | Directory scaffolding only — all files are empty |
| [modules/](modules/) | `networking`, `compute`, `security`, `database`, `monitoring` |
| [app/](app/) | Express + MSSQL application deployed into the web app and slots |
| [create_structure.sh](create_structure.sh) | Script that generated the original directory skeleton |

## Infrastructure summary

The `dev` root module ([env/dev/main.tf](env/dev/main.tf)) creates a resource group and a user-assigned managed identity, calls the five modules, and then adds private endpoints and private DNS zones for both the SQL Server and the web app.

**Networking** — a VNet with four subnets (`web`, `appgw`, `app`, `database`). The `app` subnet is delegated to `Microsoft.Web/serverFarms` and carries service endpoints for Key Vault and SQL. A static public IP with a randomised DNS label fronts the Application Gateway. A Traffic Manager profile using priority routing points its single Azure endpoint at the blue slot.

**Compute** — a Linux P1v3 App Service Plan, a Node 20 LTS web app, the blue and green slots, and an `azurerm_web_app_active_slot` resource that names blue as active. All three sites are VNet-integrated into the `app` subnet through swift connections. Two role assignments grant the managed identity Contributor and Key Vault Secrets User on the SQL Server scope.

**Security** — an Application Gateway on the `appgw` subnet (WAF_v2, autoscaling 2–5 instances) whose backend pool is the production web app's default hostname; a WAF policy in Prevention mode with OWASP 3.2 and two custom IP-match rules; three NSGs associated with the `web`, `app`, and `database` subnets; and a Key Vault holding the SQL Server and database names as secrets.

**Database** — an MSSQL Server v12.0 with a system-assigned identity and an S0 / 10 GB database using the VBS enclave type. The server is reached privately through a private endpoint in the `database` subnet.

**Monitoring** — a Log Analytics workspace (PerGB2018, 30-day retention) and an Application Insights instance linked to it, with internet ingestion and query disabled.

## Application

[app/](app/) is an Express app that renders an EJS page and exposes a CRUD API:

| Route | Method | Behaviour |
|---|---|---|
| `/` | GET | Renders `index.ejs` with the database connection status |
| `/health` | GET | Returns `200` with `{status: "healthy"}`, or `503` when the database is unreachable |
| `/api/items` | GET, POST | List all items, create an item |
| `/api/items/:id` | GET, PUT, DELETE | Read, update, delete a single item |

[app/db.js](app/db.js) parses the `DATABASE_URL` app setting (`Server=…;Database=…;User Id=…;Password=…;`) into an `mssql` pool config, falling back to `DB_SERVER` / `DB_NAME` / `DB_USER` / `DB_PASSWORD` for local development. On start, [app/server.js](app/server.js) creates the `items` table if it does not already exist. The app listens on `PORT`, defaulting to 3000, which matches the `WEBSITES_PORT` app setting.

## Prerequisites

- Terraform >= 1.0
- Azure CLI, authenticated with `az login`
- An Azure subscription with quota for a P1v3 plan, a WAF_v2 gateway, and an S0 database in the target region
- Node.js >= 20 to run or package the app locally

## Deploy

### 1. Create the state backend

```bash
cd backend
terraform init
terraform apply
```

This creates the resource group `myprojectdev-bg-rg`, the storage account `myprojectstatedevbg`, and the `tfstate` container, with blob versioning, a 30-day delete retention policy, TLS 1.2, and HTTPS-only enforced. These names are what [env/dev/backend.tf](env/dev/backend.tf) expects.

### 2. Fill in `env/dev/terraform.tfvars`

```hcl
project_name           = "bluegreen"
resource_group         = "bluegreen-rg-dev"
environment            = "dev"
subscription_id        = "<subscription-id>"
location               = "West Europe"
address_space          = ["10.0.0.0/16"]
administrator_login    = "<sql-admin-login>"
administrator_password = "<sql-admin-password>"

subnet_prefixes = {
  web      = "10.0.1.0/24"
  app      = "10.0.2.0/24"
  database = "10.0.3.0/24"
  appgw    = "10.0.4.0/24"
}
```

All four subnet keys are required: `web`, `app`, and `database` are consumed by the networking and security modules, and `appgw` provides the dedicated Application Gateway subnet. `*.tfvars` is git-ignored.

### 3. Apply

```bash
cd env/dev
terraform init
terraform plan
terraform apply
```

### 4. Deploy the application

```bash
cd app
npm install
zip -r ../app.zip . -x "node_modules/*"

az webapp deploy \
  --resource-group bluegreen-rg-dev \
  --name bluegreen-webapp-dev \
  --slot staging \
  --src-path ../app.zip \
  --type zip
```

`SCM_DO_BUILD_DURING_DEPLOYMENT` is set to `true`, so Oryx runs `npm install` on the platform during deployment.

## Blue-green workflow

1. Deploy the new version to the idle slot — `staging` (blue) or `staging2` (green).
2. Validate it on its own hostname, `https://bluegreen-webapp-staging-dev.azurewebsites.net` or `https://bluegreen-webapp-staging2-dev.azurewebsites.net`.
3. Swap. Either point `azurerm_web_app_active_slot.acive_slot` at the other slot in [modules/compute/main.tf](modules/compute/main.tf#L94-L96) and re-apply, or swap out of band:
   ```bash
   az webapp deployment slot swap \
     --resource-group bluegreen-rg-dev \
     --name bluegreen-webapp-dev \
     --slot staging \
     --target-slot production
   ```
4. Roll back by swapping again — the previous build is still sitting in the slot you swapped out of.
5. Alternate slots on each release: blue, then green, then blue.

## Input variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_name` | `string` | — | Name prefix for every resource |
| `resource_group` | `string` | — | Resource group name |
| `environment` | `string` | — | Environment suffix (`dev`) |
| `subscription_id` | `string` | — | Target Azure subscription |
| `location` | `string` | `East US` | Azure region |
| `address_space` | `list(string)` | — | VNet address space |
| `subnet_prefixes` | `map(string)` | — | CIDR per subnet: `web`, `app`, `database`, `appgw` |
| `administrator_login` | `string` | — | SQL Server administrator login |
| `administrator_password` | `string` (sensitive) | — | SQL Server administrator password |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the created resource group |
| `location` | Region of the resource group |
| `environment` | Environment suffix |
| `subnet_prefixes` | The subnet CIDR map that was passed in |
| `subnet_ids` | The entire networking module object |
| `public_ip_id` | ID of the static public IP |
| `user_assigned_identity_id` | Resource ID of the managed identity |
| `user_assigned_identity_principal_id` | Principal ID of the managed identity |
| `user_assigned_identity_tenant_id` | Tenant ID of the managed identity |

## Provider and state

The `dev` environment pins `hashicorp/azurerm` at exactly `4.1.0` and sets `resource_group.prevent_deletion_if_contains_resources = false`, so `terraform destroy` removes the resource group along with its contents. The `backend/` configuration uses `~> 3.0` and holds its own state locally.

## Tear down

```bash
cd env/dev
terraform destroy

cd ../../backend
terraform destroy
```

The database sets `prevent_destroy = false` and the state storage account does the same, so neither blocks a destroy. The Key Vault has purge protection enabled with a 7-day soft-delete retention, so its name cannot be reused until the retention period expires.
