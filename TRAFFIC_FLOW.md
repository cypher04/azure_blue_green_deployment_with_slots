# Traffic Flow

How a request reaches the application, how the application reaches the database, and what changes when the slots swap. All values come from the `dev` configuration (`project_name = "bluegreen"`, `environment = "dev"`).

## Two ingress paths

The deployment exposes two independent front doors. They resolve to different targets.

```
                        ┌──────────────────────────────┐
                        │           Client             │
                        └───────────┬──────────────────┘
                                    │
          ┌─────────────────────────┴─────────────────────────┐
          │                                                   │
   Path A: Traffic Manager                          Path B: Public IP
   bluegreen-tm-dev.trafficmanager.net              bluegreen-dns-dev-<hex>
          │                                            .westeurope.cloudapp.azure.com
          │  CNAME, TTL 100 s                                 │
          │  Priority routing, one endpoint                   │
          │  Monitor: HTTPS:443 GET /                         │
          ▼                                                   ▼
   Blue slot                                        Application Gateway
   bluegreen-webapp-staging-dev                     bluegreen-appgw-dev
   .azurewebsites.net                               listener HTTP:80
                                                            │
                                                    WAF policy (Prevention)
                                                            │
                                                    backend pool:
                                                    bluegreen-webapp-dev
                                                    .azurewebsites.net
                                                    over HTTP:80
                                                            ▼
                                                    Production web app
```

**Path A — Traffic Manager.** The profile `bluegreen-traman-dev` publishes `bluegreen-tm-dev.trafficmanager.net` with a 100-second TTL and priority routing. Its one Azure endpoint, priority 1, has `target_resource_id` set to the **blue slot**, so DNS answers point clients at `bluegreen-webapp-staging-dev.azurewebsites.net`. Health is probed with `HTTPS GET /` on port 443 every 30 seconds, timing out at 10 seconds, tolerating 3 consecutive failures before the endpoint is marked degraded. With a single endpoint there is nowhere to fail over to; a degraded endpoint simply stops being advertised.

**Path B — Application Gateway.** The static public IP is the gateway's frontend. The listener accepts plain HTTP on port 80, the WAF policy inspects the request, and the routing rule (`Basic`, priority 9) forwards it to the backend pool over HTTP on port 80. The backend pool is a single FQDN — `module.compute.fqdn`, the production app's `default_hostname` — so this path always lands on whatever code is currently in the production slot, regardless of which slot Terraform marks active.

## Request path through the Application Gateway

```
1. Client → http://bluegreen-dns-dev-<hex>.westeurope.cloudapp.azure.com/
              │
2. Public IP (static) → frontend IP configuration "appgw-frontend-ip"
              │
3. Listener "appgw-http-listener", HTTP, port 80
              │
4. WAF policy bluegreen-wafpolicy-dev, Prevention mode
     • Custom Rule1 (prio 1) — Block if source IP ∈ 192.168.1.0/24, 10.0.0.0/24
     • Custom Rule2 (prio 2) — Block if source IP ∈ 192.168.1.0/24
                               AND User-Agent contains "Windows"
     • OWASP 3.2 managed rules
         – 920300 → Log
         – 920440 → Block
     • Exclusions: header x-company-secret-header, cookie *too-tasty
     • Request body inspected, 128 KB max body, 100 MB max upload
              │
5. Routing rule "appgw-routing-rule" (Basic, priority 9)
              │
6. Gateway instances in subnet bluegreen-subnet-appgw-dev (10.0.4.0/24),
   autoscaled between 2 and 5
              │
7. Backend HTTP settings "appgw-backend-http-settings"
     HTTP:80, cookie affinity disabled, host name not taken from backend address
              │
8. Health probe "appgw-health-probe" gates the pool
     HTTP GET / with Host: localhost, every 30 s, 30 s timeout, 3 failures
              │
9. Backend pool "appgw-backend-pool"
     bluegreen-webapp-dev.azurewebsites.net
              │
10. App Service front end → container listening on port 3000 (WEBSITES_PORT)
```

## NSG traversal

Three NSGs sit on the subnets. The Application Gateway's own subnet (`appgw`, 10.0.4.0/24) has no NSG associated, so gateway traffic is unfiltered at that hop.

| Hop | Subnet | NSG | Effective rules |
|---|---|---|---|
| Private endpoint for the web app | `web` 10.0.1.0/24 | `bluegreen-nsg-dev` | Inbound TCP/443 from any; inbound TCP/65200-65535 from `GatewayManager` |
| App Service VNet integration | `app` 10.0.2.0/24 | `bluegreen-app-nsg-dev` | Inbound TCP/443 from any; outbound TCP/443 to any |
| Private endpoint for SQL | `database` 10.0.3.0/24 | `bluegreen-nsg-dev` | Inbound TCP/1433 from 10.0.2.0/24 only |

Everything not matched by these rules falls through to the Azure default rules, which permit intra-VNet traffic and general outbound access.

## Application to database

```
Production app / blue slot / green slot
  (all three swift-integrated into bluegreen-subnet-app-dev, 10.0.2.0/24)
  vnet_route_all_enabled = 1 → all outbound traffic goes through the VNet
              │
  app/db.js parses DATABASE_URL:
    Server=bluegreen-mssqlsrv-dev.database.windows.net
    Database=bluegreen-mssqldb-dev
    User Id / Password from the tfvars admin credentials
    encrypt: true, trustServerCertificate: false
              │
  DNS lookup for bluegreen-mssqlsrv-dev.database.windows.net
              │
  privatelink.database.windows.net zone is linked to the VNet
  → resolves to the private endpoint address in 10.0.3.0/24
              │
  Outbound TCP/1433 leaves the app subnet
              │
  Database NSG: Allow-https-Inbound-data admits TCP/1433 from 10.0.2.0/24
              │
  Private endpoint bluegreen-pe-sql-dev (sub-resource sqlServer)
              │
  bluegreen-mssqlsrv-dev → bluegreen-mssqldb-dev (S0, 10 GB)
```

The `app` subnet also carries service endpoints for `Microsoft.Sql` and `Microsoft.KeyVault`, giving a second route to those services over the Azure backbone. The SQL Server keeps `public_network_access_enabled = true`, so its public endpoint stays reachable alongside the private one.

Connection pooling is handled in [app/db.js](app/db.js): a single `mssql` pool per instance, max 10 connections, 30-second idle timeout, created lazily on first request and reused afterwards.

## Application routes

| Request | Handler | Database interaction |
|---|---|---|
| `GET /` | [app/server.js](app/server.js) | `SELECT 1 AS connected`; renders `index.ejs` with `Connected` or `Disconnected` |
| `GET /health` | [app/server.js](app/server.js) | `SELECT 1`; `200` healthy or `503` unhealthy |
| `GET /api/items` | [app/routes/items.js](app/routes/items.js) | `SELECT * FROM items ORDER BY created_at DESC` |
| `GET /api/items/:id` | [app/routes/items.js](app/routes/items.js) | Parameterised `SELECT` by id |
| `POST /api/items` | [app/routes/items.js](app/routes/items.js) | `INSERT … OUTPUT INSERTED.*` |
| `PUT /api/items/:id` | [app/routes/items.js](app/routes/items.js) | `UPDATE` then re-`SELECT` |
| `DELETE /api/items/:id` | [app/routes/items.js](app/routes/items.js) | `DELETE` by id |

Both health surfaces — the Traffic Manager monitor and the Application Gateway probe — request `/`, not `/health`, so a running app returns 200 even while the database is down.

On startup the app issues a `CREATE TABLE items` guarded by an `IF NOT EXISTS` check. If the database is unreachable the error is logged and the server still starts.

## Managed identity path

```
bluegreen-identity-dev (user-assigned)
  │
  ├─ attached to bluegreen-webapp-dev as its identity
  │    and set as key_vault_reference_identity_id
  │
  ├─ attached to bluegreen-appgw-dev
  │
  ├─ Key Vault access policy on bluegreen-dev-kvbg
  │    secrets: Get, List, Set, Delete, Purge, Recover
  │    keys: Get, List
  │    → mssql-server-name, mssql-database-name
  │
  └─ role assignments, both scoped to the SQL Server resource ID
       Contributor
       Key Vault Secrets User
```

The application does not read the Key Vault secrets at runtime — its credentials arrive through the `DATABASE_URL` app setting, which Terraform interpolates literally from the `administrator_login` and `administrator_password` variables.

## Slot swap

Three sites share the plan `bluegreen-asp-dev`, each with its own hostname:

| Site | Hostname |
|---|---|
| Production | `bluegreen-webapp-dev.azurewebsites.net` |
| Blue (`staging`) | `bluegreen-webapp-staging-dev.azurewebsites.net` |
| Green (`staging2`) | `bluegreen-webapp-staging2-dev.azurewebsites.net` |

```
Before the swap
   Production  ── v1.0 ──►  App Gateway backend pool points here
   Blue        ── v2.0      Traffic Manager endpoint points here
   Green       ── idle

Swap blue ⇄ production
   Production  ── v2.0      App Gateway now serves v2.0
   Blue        ── v1.0      previous build, ready to swap back
   Green       ── idle

Roll back — swap again
   Production  ── v1.0
   Blue        ── v2.0
```

A swap exchanges the running workers behind the two hostnames. Neither hostname changes, so neither the Application Gateway backend pool nor the Traffic Manager endpoint needs updating — the gateway keeps pointing at the production hostname and picks up the new code, and the Traffic Manager endpoint keeps pointing at the blue slot and picks up the swapped-out code.

`azurerm_web_app_active_slot.acive_slot` in [modules/compute/main.tf](modules/compute/main.tf#L94-L96) declares the swap in Terraform. Changing its `slot_id` to `azurerm_linux_web_app_slot.green.id` and applying performs the swap through the provider. The equivalent out-of-band operation:

```bash
az webapp deployment slot swap \
  --resource-group bluegreen-rg-dev \
  --name bluegreen-webapp-dev \
  --slot staging \
  --target-slot production
```

Neither slot declares `app_settings` of its own, so all settings — including `DATABASE_URL` — travel with the swap and every site talks to the same `bluegreen-mssqldb-dev` database. There are no sticky settings and no slot-specific connection strings.

## Deployment traffic

```
Local machine / CI
      │  az webapp deploy --src-path app.zip --type zip --slot staging
      ▼
Kudu / SCM endpoint for bluegreen-webapp-dev
      │  SCM_DO_BUILD_DURING_DEPLOYMENT=true → Oryx runs npm install
      ▼
Blue slot worker restarts, listening on port 3000
      │  validate against bluegreen-webapp-staging-dev.azurewebsites.net
      ▼
Swap into production
```
