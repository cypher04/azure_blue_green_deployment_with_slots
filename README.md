# Azure Blue-Green Deployment with App Service Slots

## Overview

This project provisions a **blue-green deployment architecture** on Azure using **App Service deployment slots**, managed entirely through Terraform. It enables zero-downtime releases with instant rollback by routing traffic between a production slot and two staging slots (blue and green) via Azure Traffic Manager.

The infrastructure follows a **multi-tier, modular design** with isolated subnets for web, application, and database layers, secured by Network Security Groups, a Web Application Firewall (WAF), and Azure Key Vault for secrets management.

### Key Capabilities

- **Zero-downtime deployments** through App Service slot swapping
- **Instant rollback** by reverting the active slot designation
- **WAF protection** with OWASP 3.2 managed rules and custom IP-based rules
- **Secret management** via Azure Key Vault with User Assigned Managed Identity
- **Network isolation** with dedicated subnets and NSG rules per tier
- **Traffic routing** through Azure Traffic Manager with priority-based routing and health monitoring
- **Remote state** stored in Azure Blob Storage with versioning and soft delete

---

## Architecture

```
                        Internet
                           |
                   Traffic Manager
                  (Priority Routing)
                           |
                      Public IP
                       (Static)
                           |
               Application Gateway (WAF_v2)
              WAF Policy (OWASP 3.2, Prevention)
                           |
        ┌──────────────────────────────────────────┐
        │          Virtual Network (VNet)           │
        │                                          │
        │  ┌────────────────────────────────────┐  │
        │  │  Web Subnet          [Web NSG]     │  │
        │  │  Application Gateway               │  │
        │  └────────────────────────────────────┘  │
        │                  |                       │
        │  ┌────────────────────────────────────┐  │
        │  │  App Subnet          [App NSG]     │  │
        │  │  App Service Plan (Linux, P1v3)    │  │
        │  │  ├─ Production Web App             │  │
        │  │  ├─ Blue Slot (staging)            │  │
        │  │  └─ Green Slot (staging2)          │  │
        │  │  VNet Integration (all slots)      │  │
        │  └────────────────────────────────────┘  │
        │                  |                       │
        │  ┌────────────────────────────────────┐  │
        │  │  Database Subnet     [Data NSG]    │  │
        │  │  MSSQL Server (v12.0, TLS 1.2)     │  │
        │  │  MSSQL Database (S0, 10 GB)        │  │
        │  └────────────────────────────────────┘  │
        └──────────────────────────────────────────┘

        ┌──────────────────────────────────────────┐
        │  Supporting Services                     │
        │  • Key Vault (secrets for DB creds)      │
        │  • User Assigned Managed Identity        │
        │  • Log Analytics Workspace               │
        │  • Application Insights                  │
        └──────────────────────────────────────────┘
```

---

## Project Structure

```
├── README.md
├── ARCHITECTURE.md
├── PROJECT_STRUCTURE.txt
│
├── backend/                    # Remote state infrastructure
│   ├── main.tf                 # Storage Account + Container for tfstate
│   └── providers.tf            # AzureRM provider config
│
├── env/                        # Per-environment root modules
│   ├── dev/
│   │   ├── main.tf             # Root module: wires all child modules
│   │   ├── variables.tf        # Input variable declarations
│   │   ├── outputs.tf          # Root-level outputs
│   │   ├── providers.tf        # AzureRM v4.1.0 provider
│   │   ├── backend.tf          # Azure Storage backend config
│   │   └── terraform.tfvars    # Environment-specific values
│   ├── stage/                  # Staging environment (same structure)
│   └── prod/                   # Production environment (same structure)
│
├── modules/
│   ├── compute/                # App Service Plan, Web App, Slots, VNet Integration
│   ├── networking/             # VNet, Subnets, Public IP, Traffic Manager
│   ├── security/               # Application Gateway, WAF, NSGs, Key Vault
│   ├── database/               # MSSQL Server + Database
│   └── monitoring/             # Log Analytics, Application Insights
│
└── workspace/                  # VS Code workspace files
```

---

## Modules

### Compute

Provisions the application hosting layer.

| Resource | Description |
|---|---|
| `azurerm_service_plan` | Linux App Service Plan (P1v3 SKU) |
| `azurerm_linux_web_app` | Production web app with UserAssigned identity, client certificate auth, and Key Vault-backed app settings |
| `azurerm_linux_web_app_slot` (blue) | Staging slot for new deployments |
| `azurerm_linux_web_app_slot` (green) | Secondary staging slot for alternating releases |
| `azurerm_web_app_active_slot` | Designates which slot receives production traffic |
| `azurerm_app_service_virtual_network_swift_connection` | VNet integration for the production app and both slots |
| `azurerm_role_assignment` | Grants Contributor on MSSQL Server and Key Vault Secrets User to the managed identity |

### Networking

Provisions the network foundation and traffic routing.

| Resource | Description |
|---|---|
| `azurerm_virtual_network` | VNet with configurable address space |
| `azurerm_subnet` (web) | Hosts the Application Gateway |
| `azurerm_subnet` (app) | Hosts App Service with `Microsoft.Web/serverFarms` delegation |
| `azurerm_subnet` (database) | Hosts the MSSQL Server |
| `azurerm_public_ip` | Static public IP with DNS label (used by Application Gateway and Traffic Manager) |
| `azurerm_traffic_manager_profile` | Priority-based routing with HTTPS health monitoring (30s interval, 10s timeout) |
| `azurerm_traffic_manager_azure_endpoint` | Routes traffic to the static public IP |

### Security

Provisions the WAF, NSGs, and secrets management.

| Resource | Description |
|---|---|
| `azurerm_application_gateway` | WAF_v2 tier with autoscaling (2-5 instances), health probes, and backend routing |
| `azurerm_web_application_firewall_policy` | OWASP 3.2 in Prevention mode with custom IP-block rules and header/cookie exclusions |
| `azurerm_network_security_group` (x3) | Dedicated NSGs for web, app, and database subnets |
| `azurerm_network_security_rule` | HTTPS inbound/outbound rules; AppGW management ports (65200-65535) on web NSG |
| `azurerm_subnet_network_security_group_association` (x3) | Associates each NSG with its respective subnet |
| `azurerm_key_vault` | Stores database credentials; access policies for the managed identity and the Terraform executor |
| `azurerm_key_vault_secret` (x2) | Stores MSSQL server name and database name |

### Database

Provisions the data tier.

| Resource | Description |
|---|---|
| `azurerm_mssql_server` | SQL Server v12.0, TLS 1.2 minimum, public network access disabled, SystemAssigned identity |
| `azurerm_mssql_database` | S0 SKU, 10 GB max size, SQL_Latin1_General_CP1_CI_AS collation, VBS enclave |

### Monitoring

Provisions observability resources.

| Resource | Description |
|---|---|
| `azurerm_log_analytics_workspace` | PerGB2018 SKU, 30-day retention |
| `azurerm_application_insights` | Web application type, linked to Log Analytics workspace, internet ingestion/query disabled |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.50
- An active Azure subscription with sufficient quota for the target region
- An Azure Storage Account pre-provisioned for remote state (see `backend/` directory)
- Authenticated Azure CLI session (`az login`)

---

## Input Variables

| Variable | Type | Description | Sensitive |
|---|---|---|---|
| `project_name` | `string` | Name prefix used for all resources | No |
| `resource_group` | `string` | Name of the resource group | No |
| `environment` | `string` | Deployment environment (e.g., `dev`, `stage`, `prod`) | No |
| `subscription_id` | `string` | Azure subscription ID | No |
| `location` | `string` | Azure region (default: `East US`) | No |
| `address_space` | `list(string)` | VNet address space (e.g., `["10.0.0.0/16"]`) | No |
| `subnet_prefixes` | `map(string)` | Subnet CIDR blocks keyed by tier (`web`, `app`, `database`) | No |
| `administrator_login` | `string` | SQL Server administrator username | No |
| `administrator_password` | `string` | SQL Server administrator password | **Yes** |

> **Important**: Never commit `terraform.tfvars` files containing sensitive values to version control. Use environment variables, Azure Key Vault references, or a `.gitignore` entry to protect secrets.

---

## Usage

### 1. Provision the Remote State Backend

```bash
cd backend
terraform init
terraform apply
```

This creates the Azure Storage Account and blob container used for Terraform remote state.

### 2. Configure Environment Variables

Create a `terraform.tfvars` file in the target environment directory (e.g., `env/dev/`) with required values:

```hcl
project_name        = "myproject"
environment         = "dev"
subscription_id     = "<your-subscription-id>"
location            = "West Europe"
resource_group      = "<your-resource-group>"
address_space       = ["10.0.0.0/16"]
administrator_login = "<your-sql-admin>"
administrator_password = "<your-sql-password>"

subnet_prefixes = {
  web      = "10.0.1.0/24"
  app      = "10.0.2.0/24"
  database = "10.0.3.0/24"
}
```

### 3. Deploy Infrastructure

```bash
cd env/dev
terraform init
terraform plan
terraform apply
```

### 4. Deploy to Other Environments

Repeat the same steps in `env/stage/` or `env/prod/` with environment-specific `.tfvars` files.

---

## Blue-Green Deployment Workflow

1. **Initial state**: The production web app serves live traffic. Blue and green slots are idle.
2. **Deploy new version**: Push the new application version to the **blue** slot.
3. **Validate**: Test the blue slot URL to verify the deployment.
4. **Swap**: Update `azurerm_web_app_active_slot` to point to the blue slot, then run `terraform apply`. Traffic shifts instantly.
5. **Rollback** (if needed): Revert the active slot to the previous configuration and reapply.
6. **Next release**: Deploy to the **green** slot and repeat the cycle.

```
Cycle 1:  Production ← Swap ← Blue (v2.0)
Cycle 2:  Production ← Swap ← Green (v3.0)
Cycle 3:  Production ← Swap ← Blue (v4.0)
...
```

---

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the created resource group |
| `location` | Azure region of the deployment |
| `environment` | Target environment name |
| `subnet_prefixes` | Map of subnet CIDR blocks |
| `subnet_ids` | Networking module subnet ID outputs |
| `public_ip_id` | ID of the static public IP |
| `user_assigned_identity_id` | ID of the User Assigned Managed Identity |
| `user_assigned_identity_principal_id` | Principal ID of the managed identity |
| `user_assigned_identity_tenant_id` | Tenant ID of the managed identity |

---

## Module Dependency Graph

```
networking ──────────────┐
                         ├──► security
database ──► compute ────┘
monitoring (independent)
```

- **compute** depends on **database** (receives server name, database name, server ID, database ID)
- **security** depends on **networking** (receives subnet IDs, public IP) and **compute** (ensures web app exists before NSG associations)
- **monitoring** has no inter-module dependencies

---

## Terraform State Backend

State is stored remotely in Azure Blob Storage:

| Setting | Value |
|---|---|
| Storage Account | Provisioned via `backend/main.tf` |
| Container | `tfstate` |
| Blob Versioning | Enabled |
| Delete Retention | 30 days |
| TLS | 1.2 minimum |
| HTTPS Only | Enabled |

---

## Security Considerations

- **Key Vault**: Purge protection enabled, soft delete with 7-day retention. Access policies scoped to the User Assigned Managed Identity and the Terraform executor.
- **MSSQL Server**: Public network access disabled. TLS 1.2 enforced. SystemAssigned identity enabled.
- **WAF**: OWASP 3.2 ruleset in Prevention mode. Custom rules block traffic from specified IP ranges.
- **NSGs**: Least-privilege inbound/outbound rules per subnet tier. Application Gateway management ports (65200-65535) explicitly allowed on the web subnet NSG.
- **App Service**: Client certificate authentication required. Auth settings enabled with redirect for unauthenticated clients.
- **Sensitive variables**: The `administrator_password` variable is marked `sensitive` in Terraform to prevent it from appearing in plan output or state logs.

---

## Clean Up

To destroy all provisioned resources:

```bash
cd env/dev
terraform destroy
```

To also remove the remote state backend:

```bash
cd backend
terraform destroy
```

---

## License

This project is provided as-is for educational and reference purposes.