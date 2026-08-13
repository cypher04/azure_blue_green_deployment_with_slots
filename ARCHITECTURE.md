# Architecture

Every resource described here is defined in [env/dev/main.tf](env/dev/main.tf) or in one of the five modules it calls. Names use the `dev` values from `terraform.tfvars`: `project_name = "bluegreen"`, `environment = "dev"`, `location = "West Europe"`.

## Topology

```
                            Internet
                                │
                ┌───────────────┴───────────────┐
                │                               │
     bluegreen-tm-dev                  bluegreen-dns-dev-<hex>
     .trafficmanager.net               .westeurope.cloudapp.azure.com
     (Traffic Manager, Priority)       (Static Public IP)
                │                               │
                │                    Application Gateway WAF_v2
                │                    bluegreen-appgw-dev
                │                    listener HTTP:80 → backend HTTP:80
                │                               │
                │                    backend pool = production
                │                    web app default hostname
                │                               │
     target = blue slot ──────────────────────► │
                                                │
 ┌──────────────────────────────────────────────┼─────────────────────────┐
 │  VNet  bluegreen-vnet-dev  10.0.0.0/16       │                         │
 │                                              │                         │
 │  appgw subnet 10.0.4.0/24 ───────────────────┘                         │
 │     Application Gateway instances (autoscale 2–5)                      │
 │                                                                        │
 │  web subnet 10.0.1.0/24            [NSG bluegreen-nsg-dev]             │
 │     Private endpoint  bluegreen-pe-webapp-dev  (sites)                 │
 │                                                                        │
 │  app subnet 10.0.2.0/24            [NSG bluegreen-app-nsg-dev]         │
 │     delegation: Microsoft.Web/serverFarms                              │
 │     service endpoints: Microsoft.KeyVault, Microsoft.Sql               │
 │     App Service Plan  bluegreen-asp-dev  (Linux, P1v3)                 │
 │       ├─ bluegreen-webapp-dev             (production)                 │
 │       ├─ bluegreen-webapp-staging-dev     (blue,  active slot)         │
 │       └─ bluegreen-webapp-staging2-dev    (green)                      │
 │     all three swift-integrated into this subnet                        │
 │                                                                        │
 │  database subnet 10.0.3.0/24       [NSG bluegreen-nsg-dev]             │
 │     Private endpoint  bluegreen-pe-sql-dev  (sqlServer)                │
 └────────────────────────────────────────────────────────────────────────┘

  Private DNS zones linked to the VNet
    privatelink.azurewebsites.net    ← bluegreen-dns-link-webapp-dev
    privatelink.database.windows.net ← bluegreen-dns-link-sql-dev

  Outside the VNet
    bluegreen-mssqlsrv-dev / bluegreen-mssqldb-dev   (S0, 10 GB)
    bluegreen-dev-kvbg                                (Key Vault)
    bluegreen-identity-dev                            (User-assigned identity)
    bluegreen-loganalytics-dev + bluegreen-appinsights-dev
```

## Root module

[env/dev/main.tf](env/dev/main.tf) creates three things directly, then calls the modules and adds the private networking layer.

| Resource | Detail |
|---|---|
| `azurerm_resource_group.name` | `bluegreen-rg-dev` in `West Europe` |
| `data.azurerm_client_config.current` | Identity running Terraform, used for a Key Vault access policy |
| `azurerm_user_assigned_identity.uai` | `bluegreen-identity-dev`; its ID, principal ID, and tenant ID are passed to both `compute` and `security` |

### Private endpoints and DNS

| Resource | Subnet | Sub-resource | Zone |
|---|---|---|---|
| `azurerm_private_endpoint.pe-sql` | `database` | `sqlServer` | `privatelink.database.windows.net` |
| `azurerm_private_endpoint.pe-webapp` | `web` | `sites` | `privatelink.azurewebsites.net` |

Both zones get an `azurerm_private_dns_zone_virtual_network_link` to `bluegreen-vnet-dev`, so name resolution for the SQL Server and the web app inside the VNet returns the private endpoint addresses.

### Module wiring

```
azurerm_resource_group ──► every module
azurerm_user_assigned_identity ──► compute, security

networking ──► subnet_ids, public_ip_id, vnet_id
     │
     ├──► compute   (subnet_ids: web, app, database)
     ├──► security  (subnet_ids: web, app, database, appgw + public_ip_id)
     └──► database  (subnet_ids: web, app, database)

database ──► compute  (server_name, database_name, server_id, database_id)
database ──► security (server_name, database_name)
compute  ──► security (fqdn — becomes the App Gateway backend pool)
compute  ──► networking (blue_slot_id, green_slot_id)
security ──► compute  (keyvault_name)

monitoring — no inter-module inputs beyond name, location, environment, resource group
```

`compute` carries `depends_on = [module.database]` and `security` carries `depends_on = [module.networking]`. The networking module also takes `public_ip_id = module.networking.public_ip_id`, a self-reference that is declared but unused by any resource in the module.

## Networking module

[modules/networking/main.tf](modules/networking/main.tf)

| Resource | Configuration |
|---|---|
| `random_id.server` | 4 bytes, `keepers = { azi = 1 }`; supplies the public IP DNS label suffix |
| `azurerm_virtual_network.vnet` | `bluegreen-vnet-dev`, `10.0.0.0/16` |
| `azurerm_subnet.web` | `10.0.1.0/24` |
| `azurerm_subnet.appgw` | `10.0.4.0/24`, holds the Application Gateway |
| `azurerm_subnet.app` | `10.0.2.0/24`, delegated to `Microsoft.Web/serverFarms` with the `virtualNetworks/subnets/action` action; service endpoints `Microsoft.KeyVault` and `Microsoft.Sql` |
| `azurerm_subnet.database` | `10.0.3.0/24` |
| `azurerm_public_ip.pip` | Static, DNS label `bluegreen-dns-dev-<random hex>` |
| `azurerm_traffic_manager_profile.traman` | `bluegreen-traman-dev`, Enabled, `Priority` routing; DNS relative name `bluegreen-tm-dev`, TTL 100 s; monitor HTTPS:443 on `/`, interval 30 s, timeout 10 s, 3 tolerated failures |
| `azurerm_traffic_manager_azure_endpoint.tramanend` | `bluegreen-traman-endpoint-dev`, priority 1, `target_resource_id = var.blue_slot_id` |

Outputs: `subnet_ids` (a map keyed `web`, `app`, `database`, `appgw`), `public_ip_id`, `public_ip`, `vnet_id`.

## Compute module

[modules/compute/main.tf](modules/compute/main.tf)

| Resource | Configuration |
|---|---|
| `azurerm_service_plan.serveplan` | `bluegreen-asp-dev`, Linux, `P1v3` |
| `azurerm_linux_web_app.webapp` | `bluegreen-webapp-dev`; Node `20-lts`; `vnet_route_all_enabled = "1"`; `UserAssigned` identity; `key_vault_reference_identity_id` set to the same identity |
| `azurerm_linux_web_app_slot.blue` | `bluegreen-webapp-staging-dev`, empty `site_config` |
| `azurerm_linux_web_app_slot.green` | `bluegreen-webapp-staging2-dev`, empty `site_config` |
| `azurerm_web_app_active_slot.acive_slot` | `slot_id` = the blue slot |
| `azurerm_app_service_virtual_network_swift_connection.asvnet-conn-webapp` | Production app → `subnet_ids["1"]` (the `app` subnet) |
| `azurerm_app_service_slot_virtual_network_swift_connection.asvnet-conn-blue` | Blue slot → `app` subnet |
| `azurerm_app_service_slot_virtual_network_swift_connection.asvnet-conn-green` | Green slot → `app` subnet |
| `azurerm_role_assignment.appservice_mssql_access` | `Contributor` for the managed identity, scoped to `server_id` |
| `azurerm_role_assignment.appservice_keyvault_access` | `Key Vault Secrets User` for the managed identity, scoped to `server_id` |

App settings on the production app:

| Setting | Value |
|---|---|
| `WEBSITES_ENABLE_APP_SERVICE_STORAGE` | `true` |
| `DATABASE_URL` | `Server=<server>.database.windows.net;Database=<db>;User Id=<login>;Password=<password>;` |
| `WEBSITES_PORT` | `3000` |
| `SCM_DO_BUILD_DURING_DEPLOYMENT` | `true` |

Neither slot declares its own `app_settings`, so both inherit whatever is present after a swap. `client_certificate_enabled`, `client_certificate_mode`, and the `auth_settings` blocks are commented out on the app and both slots.

Outputs: `service_plan_id`, `app_service_id`, `webapp_id`, `fqdn` (the app's `default_hostname`), `webapp_tenant_id`, `webapp_principal_id`, `blue_slot_id`, `green_slot_id`.

## Security module

[modules/security/main.tf](modules/security/main.tf)

### Application Gateway — `bluegreen-appgw-dev`

| Setting | Value |
|---|---|
| SKU / tier | `WAF_v2` / `WAF_v2` |
| Identity | `UserAssigned`, `bluegreen-identity-dev` |
| Autoscale | min 2, max 5 |
| Gateway IP config | `subnet_ids["3"]` — the `appgw` subnet |
| Frontend port | 80 |
| Frontend IP | The static public IP |
| Backend pool | `fqdns = [var.fqdn]` — the production web app's default hostname |
| Backend HTTP settings | Port 80, HTTP, cookie affinity disabled, `pick_host_name_from_backend_address = false` |
| Listener | HTTP on the frontend IP and port |
| Routing rule | `Basic`, priority 9, listener → backend pool |
| Probe | HTTP, host `localhost`, path `/`, interval 30 s, timeout 30 s, unhealthy threshold 3 |
| Firewall policy | `bluegreen-wafpolicy-dev` |

### WAF policy — `bluegreen-wafpolicy-dev`

Policy settings: enabled, `Prevention` mode, request body check on, 100 MB file upload limit, 128 KB max request body.

Custom rules:

| Rule | Priority | Match | Action |
|---|---|---|---|
| `Rule1` | 1 | `RemoteAddr` IPMatch `192.168.1.0/24`, `10.0.0.0/24` | Block |
| `Rule2` | 2 | `RemoteAddr` IPMatch `192.168.1.0/24` **and** `RequestHeaders:UserAgent` contains `Windows` | Block |

Managed rules: OWASP 3.2, with a `REQUEST-920-PROTOCOL-ENFORCEMENT` group override setting rule `920300` to `Log` and rule `920440` to `Block`. Two exclusions are declared — request header name `x-company-secret-header` (Equals) and request cookie name ending in `too-tasty`.

### Network Security Groups

| Terraform name | Resource name | Associated subnet |
|---|---|---|
| `web-nsg` | `bluegreen-nsg-dev` | `subnet_ids[0]` — `web` |
| `app-nsg` | `bluegreen-app-nsg-dev` | `subnet_ids[1]` — `app` |
| `data-nsg` | `bluegreen-nsg-dev` | `subnet_ids[2]` — `database` |

Rules:

| NSG | Rule | Priority | Direction | Port | Source |
|---|---|---|---|---|---|
| web | `Allow-https-Inbound-web` | 100 | Inbound | 443 | `*` |
| web | `Allow-AppGW-Management` | 200 | Inbound | 65200-65535 | `GatewayManager` |
| app | `Allow-https-Inbound-app` | 100 | Inbound | 443 | `*` |
| app | `Allow-https-Outbound-app` | 110 | Outbound | 443 | `*` |
| database | `Allow-https-Inbound-data` | 110 | Inbound | 1433 | `subnet_prefixes["app"]` |

A commented-out outbound rule remains in the database NSG block.

### Key Vault — `bluegreen-dev-kvbg`

Standard SKU, tenant taken from the user-assigned identity, `enabled_for_disk_encryption = true`, purge protection enabled, 7-day soft-delete retention.

Two access policies:

- **Managed identity** — keys `Get`/`List`; secrets `Get`, `List`, `Set`, `Delete`, `Purge`, `Recover`; storage `Get`, `List`, `Set`, `Delete`.
- **Terraform executor** (`data.azurerm_client_config.current`) — secrets `Get`, `List`, `Set`, `Delete`, `Purge`, `Recover`.

Secrets: `mssql-database-name` and `mssql-server-name`.

Outputs: `app_gateway_id` (the whole gateway object), `nsg_ids`, `firewall_id`, `keyvault_name`.

## Database module

[modules/database/main.tf](modules/database/main.tf)

| Resource | Configuration |
|---|---|
| `azurerm_mssql_server.mssqlsrv` | `bluegreen-mssqlsrv-dev`, version `12.0`, SQL authentication with the admin login and password, `public_network_access_enabled = true`, `SystemAssigned` identity, tagged with environment and project. The `minimum_tls_version` line is commented out. |
| `azurerm_mssql_database.mssqldb` | `bluegreen-mssqldb-dev`, `S0`, 10 GB, collation `SQL_Latin1_General_CP1_CI_AS`, license `BasePrice`, enclave type `VBS`, `prevent_destroy = false` |

The `azurerm_mssql_virtual_network_rule` resource is commented out; private connectivity comes from the private endpoint declared in the root module instead.

Outputs: `server_id`, `database_id`, `server_name`, `database_name`.

## Monitoring module

[modules/monitoring/main.tf](modules/monitoring/main.tf)

| Resource | Configuration |
|---|---|
| `azurerm_log_analytics_workspace.log_analytics` | `bluegreen-loganalytics-dev`, `PerGB2018`, 30-day retention |
| `azurerm_application_insights.app_insights` | `bluegreen-appinsights-dev`, type `web`, linked to the workspace, `internet_ingestion_enabled = false`, `internet_query_enabled = false` |

Outputs: `instrumentation_key`, `app_insights_id`. Neither is consumed by another module — the web app's app settings do not reference Application Insights.

## Naming convention

| Resource | Pattern | `dev` value |
|---|---|---|
| Resource group | `{project}-rg-{env}` | `bluegreen-rg-dev` |
| Managed identity | `{project}-identity-{env}` | `bluegreen-identity-dev` |
| Virtual network | `{project}-vnet-{env}` | `bluegreen-vnet-dev` |
| Subnet | `{project}-subnet-{tier}-{env}` | `bluegreen-subnet-app-dev` |
| Public IP | `{project}-pip-{env}` | `bluegreen-pip-dev` |
| Public IP DNS label | `{project}-dns-{env}-{hex}` | `bluegreen-dns-dev-a1b2c3d4` |
| Traffic Manager profile | `{project}-traman-{env}` | `bluegreen-traman-dev` |
| Traffic Manager DNS | `{project}-tm-{env}` | `bluegreen-tm-dev.trafficmanager.net` |
| Traffic Manager endpoint | `{project}-traman-endpoint-{env}` | `bluegreen-traman-endpoint-dev` |
| App Service Plan | `{project}-asp-{env}` | `bluegreen-asp-dev` |
| Web app | `{project}-webapp-{env}` | `bluegreen-webapp-dev` |
| Blue slot | `{project}-webapp-staging-{env}` | `bluegreen-webapp-staging-dev` |
| Green slot | `{project}-webapp-staging2-{env}` | `bluegreen-webapp-staging2-dev` |
| Application Gateway | `{project}-appgw-{env}` | `bluegreen-appgw-dev` |
| WAF policy | `{project}-wafpolicy-{env}` | `bluegreen-wafpolicy-dev` |
| Web / database NSG | `{project}-nsg-{env}` | `bluegreen-nsg-dev` |
| App NSG | `{project}-app-nsg-{env}` | `bluegreen-app-nsg-dev` |
| Key Vault | `{project}-{env}-kvbg` | `bluegreen-dev-kvbg` |
| MSSQL Server | `{project}-mssqlsrv-{env}` | `bluegreen-mssqlsrv-dev` |
| MSSQL Database | `{project}-mssqldb-{env}` | `bluegreen-mssqldb-dev` |
| Private endpoint | `{project}-pe-{target}-{env}` | `bluegreen-pe-sql-dev` |
| Private DNS link | `{project}-dns-link-{target}-{env}` | `bluegreen-dns-link-sql-dev` |
| Log Analytics | `{project}-loganalytics-{env}` | `bluegreen-loganalytics-dev` |
| Application Insights | `{project}-appinsights-{env}` | `bluegreen-appinsights-dev` |

## State

[env/dev/backend.tf](env/dev/backend.tf) stores state in the `tfstate` container of storage account `myprojectstatedevbg` in resource group `myprojectdev-bg-rg`, under the key `terraform.tfstate`. That account is created by [backend/main.tf](backend/main.tf) from `project_name = "myproject"` and `environment = "dev"` defaults: Standard LRS, TLS 1.2 minimum, HTTPS-only, blob versioning on, 30-day delete retention, private container access.

## Environments

Only `env/dev` is populated. `env/stage` and `env/prod` contain the same six filenames created by [create_structure.sh](create_structure.sh), all zero bytes.
