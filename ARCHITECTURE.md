# Blue-Green Deployment with Deployment Slots Architecture

## 📋 Overview

This architecture implements a **Blue-Green deployment strategy** using Azure App Service deployment slots with **Azure Traffic Manager** for intelligent traffic routing, enabling zero-downtime deployments with instant rollback capabilities. The infrastructure is secured with Web Application Firewall (WAF) and includes a multi-tier architecture with separate subnets for web, application, and database layers.

### Key Features
- **Active Slot Management**: Automated active slot designation with `azurerm_web_app_active_slot`
- **Traffic Manager**: Priority-based routing with health monitoring
- **Zero-Downtime Deployments**: Seamless slot swapping with instant rollback
- **WAF Protection**: OWASP 3.2 rules with custom bot protection
- **Multi-tier Security**: Network isolation with dedicated subnets and NSG rules

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Resource Group                              │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Virtual Network (10.0.0.0/16)             │  │
│  │                                                              │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  Web Subnet (10.0.1.0/24)                             │ │  │
│  │  │  • Application Gateway (WAF_v2)                       │ │  │
│  │  │    - Min Capacity: 2, Max Capacity: 5                │ │  │
│  │  │    - WAF Policy (OWASP 3.2)                          │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                           ↓                                  │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  App Subnet (10.0.2.0/24)                             │ │  │
│  │  │  • App Service Plan (P1v2)                            │ │  │
│  │  │  • Production Web App                                 │ │  │
│  │  │    ├─ Blue Slot (staging)                            │ │  │
│  │  │    └─ Green Slot (staging2)                          │ │  │
│  │  │  • VNet Integration (All Slots)                       │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                           ↓                                  │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  Database Subnet (10.0.3.0/24)                        │ │  │
│  │  │  • MSSQL Server (v12.0)                               │ │  │
│  │  │  • MSSQL Database (S0, 10GB)                          │ │  │
│  │  │  • VNet Rule (DB Subnet only)                         │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Public IP (Static)                                          │  │
│  │  • Connected to Application Gateway                          │  │
│  │  • Connected to Traffic Manager Endpoint                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Traffic Manager Profile                                     │  │
│  │  • Routing Method: Priority                                  │  │
│  │  • DNS: {project}-tm-{env}.trafficmanager.net               │  │
│  │  • Health Monitoring: HTTPS:443 every 30s                   │  │
│  │  • TTL: 100 seconds                                          │  │
│  │  • Endpoint: Public IP (Weight: 100, Always Serve)          │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Network Security Groups                                     │  │
│  │  • Web NSG (HTTPS:443 allowed)                              │  │
│  │  • App NSG (HTTPS:443 in/out allowed)                       │  │
│  │  • Database NSG (HTTPS:443 in/out allowed)                  │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔄 Blue-Green Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                 Blue-Green Deployment Workflow                  │
└─────────────────────────────────────────────────────────────────┘

    Initial State:
    ┌──────────────────────────────────────────────┐
    │  Production Slot (Live)                      │
    │  • Version: 1.0                              │
    │  • Receives 100% traffic                     │
    └──────────────────────────────────────────────┘
              ↓
    ┌──────────────────────────────────────────────┐
    │  Blue Slot (staging)                         │
    │  • Idle                                      │
    └──────────────────────────────────────────────┘
              ↓
    ┌──────────────────────────────────────────────┐
    │  Green Slot (staging2)                       │
    │  • Idle                                      │
    └──────────────────────────────────────────────┘

    ─────────────────────────────────────────────────

    Deployment Phase:
    ┌──────────────────────────────────────────────┐
    │  Production Slot                             │
    │  • Version: 1.0 (Still Live)                 │
    │  • Receives 100% traffic                     │
    └──────────────────────────────────────────────┘
              ↓
    ┌──────────────────────────────────────────────┐
    │  Blue Slot                                   │
    │  • Deploy Version: 2.0                       │
    │  • Testing & Validation                      │
    └──────────────────────────────────────────────┘

    ─────────────────────────────────────────────────

    After Swap (Blue → Production):
    ┌──────────────────────────────────────────────┐
    │  Production Slot                             │
    │  • Version: 2.0 (Now Live)                   │
    │  • Receives 100% traffic                     │
    └──────────────────────────────────────────────┘
              ↓
    ┌──────────────────────────────────────────────┐
    │  Blue Slot                                   │
    │  • Version: 1.0 (Previous Production)        │
    │  • Available for Instant Rollback            │
    └──────────────────────────────────────────────┘

    ─────────────────────────────────────────────────

    Next Deployment Cycle (Use Green):
    ┌──────────────────────────────────────────────┐
    │  Production Slot                             │
    │  • Version: 2.0 (Live)                       │
    │  • Receives 100% traffic                     │
    └──────────────────────────────────────────────┘
              ↓
    ┌──────────────────────────────────────────────┐
    │  Green Slot                                  │
    │  • Deploy Version: 3.0                       │
    │  • Testing & Validation                      │
    └──────────────────────────────────────────────┘
```

## 🌐 Traffic Flow

```
Internet Traffic (DNS Query)
      ↓
[Traffic Manager Profile]
   • DNS: {project}-tm-{env}.trafficmanager.net
   • Routing: Priority-based
   • Health Check: HTTPS:443 every 30s
   • Resolves to: Static Public IP
      ↓
[Static Public IP]
      ↓
[Application Gateway (WAF_v2)]
   • Port: 80 (Frontend)
   • WAF Policy: OWASP 3.2
   • Health Probe: HTTPS on /
      ↓
[Web NSG - Allow HTTPS:443]
      ↓
[Backend Pool]
      ↓
[Production Web App OR Active Slot]
   • Port: 443 (Backend)
   • VNet Integrated
      ↓
[App NSG - Allow HTTPS:443]
      ↓
[Database Connection]
   • MSSQL Server via Private Endpoint
   • Connection String in App Settings
      ↓
[Database NSG - Allow HTTPS:443]
      ↓
[MSSQL Database]
   • VNet Rule: Database Subnet Only
```

## 📦 Module Architecture

```
env/dev/
   └── main.tf (Root Module)
         ├── Creates Resource Group
         ├── Calls Networking Module
         ├── Calls Database Module
         ├── Calls Compute Module
         └── Calls Security Module

modules/
   ├── networking/
   │     ├── Random ID Generator (Server Naming)
   │     ├── Virtual Network (10.0.0.0/16)
   │     ├── Web Subnet (10.0.1.0/24)
   │     ├── App Subnet (10.0.2.0/24)
   │     ├── Database Subnet (10.0.3.0/24)
   │     ├── Public IP (Static)
   │     └── Traffic Manager Profile
   │         ├── Routing Method: Priority
   │         ├── DNS Config (TTL: 100s)
   │         ├── Health Monitor (HTTPS:443)
   │         └── Azure Endpoint (Public IP, Weight: 100)
   │
   ├── database/
   │     ├── MSSQL Server (v12.0)
   │     │   • System Assigned Identity
   │     │   • TLS 1.2 minimum
   │     ├── MSSQL Database (S0, 10GB)
   │     │   • Lifecycle: prevent_destroy
   │     └── VNet Rule (Database Subnet)
   │
   ├── compute/
   │     ├── App Service Plan (P1v2, Linux)
   │     ├── Linux Web App (Production)
   │     │   • App Settings (DB Connection)
   │     │   • VNet Integration
   │     ├── Blue Slot (staging)
   │     │   • VNet Integration
   │     │   • Designated as Active Slot
   │     ├── Green Slot (staging2)
   │     │   • VNet Integration
   │     └── Active Slot Configuration
   │         • Points to: Blue Slot (Default)
   │
   └── security/
         ├── Application Gateway (WAF_v2)
         │   • Autoscaling: 2-5 instances
         │   • Frontend: HTTP:80
         │   • Backend: HTTPS:443
         │   • Health Probe
         ├── WAF Policy
         │   • Mode: Prevention
         │   • OWASP 3.2
         │   • Custom Rules
         ├── Web NSG + Rules
         ├── App NSG + Rules
         └── Database NSG + Rules
```

## 🔐 Security Architecture

### Layer 1: Edge Security
```
Public Internet
      ↓
[Static Public IP]
      ↓
[Application Gateway WAF_v2]
   • Web Application Firewall (Prevention Mode)
   • OWASP 3.2 Rule Set
   • Custom Rules (Block Bad Bots)
   • Request Body Check: Enabled
   • File Upload Limit: 100MB
   • Max Request Size: 128KB
```

### Layer 2: Network Security
```
[Network Security Groups]
   ├── Web NSG
   │   └── Allow HTTPS:443 Inbound
   │
   ├── App NSG
   │   ├── Allow HTTPS:443 Inbound
   │   └── Allow HTTPS:443 Outbound
   │
   └── Database NSG
       ├── Allow HTTPS:443 Inbound
       └── Allow HTTPS:443 Outbound
```

### Layer 3: Application Security
```
[App Service]
   • VNet Integration (Private Subnet)
   • Database Connection via Environment Variables
   • WEBSITES_ENABLE_APP_SERVICE_STORAGE: false
   • Blue/Green Slots Isolated
```

### Layer 4: Data Security
```
[MSSQL Server]
   • Minimum TLS: 1.2
   • System Assigned Managed Identity
   • VNet Rule: Database Subnet Only
   • Encryption: VBS Enclave Type
   • Lifecycle Protection: prevent_destroy
```

## 📊 Resource Naming Convention

| Resource Type | Naming Pattern | Example |
|--------------|----------------|---------|
| Resource Group | `{project}-rg-{env}` | `bluegreen-rg-dev` |
| Virtual Network | `{project}-vnet-{env}` | `bluegreen-vnet-dev` |
| Subnet | `{project}-subnet-{tier}-{env}` | `bluegreen-subnet-web-dev` |
| Public IP | `{project}-pip-{env}` | `bluegreen-pip-dev` |
| Traffic Manager Profile | `{project}-traman-{env}` | `bluegreen-traman-dev` |
| Traffic Manager DNS | `{project}-tm-{env}` | `bluegreen-tm-dev.trafficmanager.net` |
| Traffic Manager Endpoint | `{project}-traman-endpoint-{env}` | `bluegreen-traman-endpoint-dev` |
| App Service Plan | `{project}-asp-{env}` | `bluegreen-asp-dev` |
| Web App | `{project}-webapp-{env}` | `bluegreen-webapp-dev` |
| Blue Slot | `{project}-webapp-staging-{env}` | `bluegreen-webapp-staging-dev` |
| Green Slot | `{project}-webapp-staging2-{env}` | `bluegreen-webapp-staging2-dev` |
| Application Gateway | `{project}-appgw-{env}` | `bluegreen-appgw-dev` |
| WAF Policy | `{project}-waf-policy-{env}` | `bluegreen-waf-policy-dev` |
| NSG | `{project}-{tier}-nsg-{env}` | `bluegreen-app-nsg-dev` |
| MSSQL Server | `{project}-mssqlsrv-{env}` | `bluegreen-mssqlsrv-dev` |
| MSSQL Database | `{project}-mssqldb-{env}` | `bluegreen-mssqldb-dev` |
| VNet Rule | `{project}-vnetrule-{env}` | `bluegreen-vnetrule-dev` |

## 🔄 Deployment Sequence

```
Step 1: Networking Module
   ├── Generate Random ID (for unique server names)
   ├── Create Virtual Network
   ├── Create Web Subnet
   ├── Create App Subnet
   ├── Create Database Subnet
   ├── Create Public IP (Static)
   ├── Create Traffic Manager Profile
   │   ├── Configure DNS (bluegreen-tm-dev.trafficmanager.net)
   │   ├── Configure Health Monitoring (HTTPS:443)
   │   └── Set Routing Method (Priority)
   └── Create Traffic Manager Endpoint
       ├── Link to Public IP
       └── Configure Weight (100) and Always Serve

Step 2: Database Module
   ├── Create MSSQL Server
   ├── Create MSSQL Database
   └── Create VNet Rule

Step 3: Compute Module
   ├── Create App Service Plan
   ├── Create Production Web App
   │   └── Configure DB Connection String
   ├── Create Blue Slot (staging)
   ├── Create Green Slot (staging2)
   ├── Set Active Slot (Blue Slot)
   ├── Configure VNet Integration (Production)
   ├── Configure VNet Integration (Blue Slot)
   └── Configure VNet Integration (Green Slot)

Step 4: Security Module
   ├── Create Application Gateway
   │   ├── Configure Frontend (Public IP)
   │   ├── Configure Backend Pool
   │   ├── Configure Health Probe
   │   └── Configure Routing Rules
   ├── Create WAF Policy
   │   ├── Configure OWASP Rules
   │   └── Configure Custom Rules
   ├── Create Web NSG + Rules
   ├── Create App NSG + Rules
   ├── Create Database NSG + Rules
   └── Associate NSGs to Subnets
```

## 🎯 Blue-Green Deployment Strategy

### Advantages
- **Zero Downtime**: Instant swap between slots
- **Instant Rollback**: Swap back to previous slot if issues detected
- **Testing in Production Environment**: Test new version in exact production configuration
- **Gradual Rollout**: Can use traffic routing percentages
- **Independent Slots**: Each slot has its own configuration and can be tested independently

### Deployment Steps

1. **Deploy to Blue Slot**
   ```bash
   # Deploy new version to Blue slot
   az webapp deployment source config-zip \
     --resource-group bluegreen-rg-dev \
     --name bluegreen-webapp-dev \
     --slot staging \
     --src app-v2.0.zip
   ```

2. **Validate Blue Slot**
   ```bash
   # Access Blue slot URL
   https://bluegreen-webapp-dev-staging.azurewebsites.net
   
   # Run tests and validation
   ```

3. **Swap Blue to Production**
   ```bash
   # Swap Blue slot with Production
   az webapp deployment slot swap \
     --resource-group bluegreen-rg-dev \
     --name bluegreen-webapp-dev \
     --slot staging \
     --target-slot production
   ```

4. **Monitor Production**
   ```bash
   # Monitor production metrics
   # If issues detected, swap back immediately
   ```

5. **Rollback (if needed)**
   ```bash
   # Instant rollback by swapping back
   az webapp deployment slot swap \
     --resource-group bluegreen-rg-dev \
     --name bluegreen-webapp-dev \
     --slot staging \
     --target-slot production
   ```

6. **Next Deployment Cycle**
   ```bash
   # Use Green slot for next deployment
   az webapp deployment source config-zip \
     --resource-group bluegreen-rg-dev \
     --name bluegreen-webapp-dev \
     --slot staging2 \
     --src app-v3.0.zip
   ```

## 🔍 Slot Configuration

### Active Slot Management

The infrastructure uses `azurerm_web_app_active_slot` to explicitly designate which deployment slot is active:

```hcl
resource "azurerm_web_app_active_slot" "acive_slot" {
  slot_id = azurerm_linux_web_app_slot.blue.id
}
```

**Benefits:**
- **Explicit Control**: Terraform manages which slot receives production traffic
- **Declarative State**: Active slot is defined in code, not just through portal/CLI
- **Consistent Deployments**: Ensures the correct slot is active across environments
- **Auditability**: Changes to active slot are tracked in version control

**Default Configuration:**
- Blue Slot is set as the active slot by default
- Can be changed by updating the `slot_id` reference
- Requires manual swap operations to change traffic routing

### Production Slot
- **Name**: `bluegreen-webapp-dev`
- **Environment**: Production
- **Traffic**: 100% (default)
- **VNet Integration**: App Subnet
- **Database Connection**: Production connection string

### Blue Slot (staging)
- **Name**: `bluegreen-webapp-staging-dev`
- **Environment**: Staging
- **Traffic**: 0% (testing only)
- **VNet Integration**: App Subnet
- **Database Connection**: Same as production (shared)

### Green Slot (staging2)
- **Name**: `bluegreen-webapp-staging2-dev`
- **Environment**: Staging
- **Traffic**: 0% (testing only)
- **VNet Integration**: App Subnet
- **Database Connection**: Same as production (shared)

## 📈 Monitoring and Health Checks

### Traffic Manager Health Monitoring
```
Protocol: HTTPS
Port: 443
Path: /
Interval: 30 seconds
Timeout: 10 seconds
Tolerated Failures: 3
Endpoint Weight: 100
Always Serve: Enabled
```

**Traffic Manager Benefits:**
- **DNS-level Failover**: Automatic traffic routing based on endpoint health
- **Global Load Balancing**: Distribute traffic across regions (if multi-region)
- **Performance Routing**: Route users to nearest healthy endpoint
- **Monitoring**: Continuous health checks every 30 seconds
- **Fast TTL**: 100-second TTL for quick DNS propagation

### Application Gateway Health Probe
```
Name: appgw-health-probe
Protocol: HTTPS
Host: localhost
Path: /
Interval: 30 seconds
Timeout: 30 seconds
Unhealthy Threshold: 3 attempts
```

### WAF Monitoring
- **Mode**: Prevention
- **Request Body Check**: Enabled
- **File Upload Limit**: 100MB
- **Max Request Body Size**: 128KB
- **Rule Set**: OWASP 3.2
- **Custom Rules**: Block bad bots

## 🔧 Key Configuration Details

### App Service Configuration
```hcl
App Settings:
  WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  DATABASE_URL = "Server={server};Database={db};User Id={user};Password={pwd};"
  WEBSITES_PORT = "3000"

SKU: P1v2
OS: Linux
VNet Integration: Enabled on all slots
```

### Database Configuration
```hcl
MSSQL Server:
  Version: 12.0
  TLS: 1.2 minimum
  Identity: System Assigned
  
MSSQL Database:
  SKU: S0
  Max Size: 10GB
  Collation: SQL_Latin1_General_CP1_CI_AS
  License Type: BasePrice
  Enclave Type: VBS
  Lifecycle: prevent_destroy enabled
```

### Traffic Manager Configuration
```hcl
Profile:
  Name: bluegreen-traman-dev
  Status: Enabled
  Routing Method: Priority
  
DNS Configuration:
  Relative Name: bluegreen-tm-dev
  FQDN: bluegreen-tm-dev.trafficmanager.net
  TTL: 100 seconds
  
Health Monitoring:
  Protocol: HTTPS
  Port: 443
  Path: /
  Interval: 30 seconds
  Timeout: 10 seconds
  Tolerated Failures: 3
  
Endpoint:
  Type: Azure Endpoint
  Target: Public IP (Static)
  Weight: 100
  Always Serve: Enabled
```

### Application Gateway Configuration
```hcl
SKU: WAF_v2
Autoscaling:
  Min Capacity: 2
  Max Capacity: 5
  
Frontend:
  Port: 80
  IP: Public Static IP
  
Backend:
  Port: 443
  Protocol: HTTPS
  
WAF Policy:
  Mode: Prevention
  OWASP: 3.2
```

## 📝 Best Practices Implemented

1. **High Availability**
   - Traffic Manager for DNS-level health monitoring and routing
   - Application Gateway autoscaling (2-5 instances)
   - Multiple deployment slots for zero-downtime deployments
   - Active slot configuration managed via Infrastructure as Code

2. **Security**
   - WAF with OWASP 3.2 rules
   - Network segmentation with separate subnets
   - NSG rules limiting traffic
   - VNet integration for all components
   - TLS 1.2 minimum for database

3. **Resilience**
   - Database lifecycle protection (prevent_destroy)
   - Health probes for automatic failover
   - Instant rollback capability via slot swaps

4. **Operational Excellence**
   - Modular Terraform structure
   - Consistent naming conventions
   - Environment-based configurations
   - Managed identities for security

## 🚀 Quick Start

```bash
# Initialize Terraform
cd env/dev
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply

# Verify deployment
az webapp list --resource-group bluegreen-rg-dev --output table
az webapp deployment slot list --resource-group bluegreen-rg-dev --name bluegreen-webapp-dev --output table

# Verify Traffic Manager
az network traffic-manager profile list --resource-group bluegreen-rg-dev --output table
az network traffic-manager endpoint list --resource-group bluegreen-rg-dev --profile-name bluegreen-traman-dev --output table

# Test DNS resolution
nslookup bluegreen-tm-dev.trafficmanager.net
```

## 📚 Additional Resources

- [Azure App Service Deployment Slots](https://docs.microsoft.com/en-us/azure/app-service/deploy-staging-slots)
- [Blue-Green Deployment Pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/blue-green-deployment)
- [Azure Application Gateway WAF](https://docs.microsoft.com/en-us/azure/web-application-firewall/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
