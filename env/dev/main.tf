resource "azurerm_resource_group" "name" {
    name     = "${var.project_name}-rg-${var.environment}"
    location = var.location
}

data "azurerm_client_config" "current" {

}

resource "azurerm_user_assigned_identity" "uai" {
    name                = "${var.project_name}-identity-${var.environment}"
    resource_group_name = var.resource_group
    location            = var.location

    depends_on = [ azurerm_resource_group.name ]
}

module "compute" {
    source              = "../../modules/compute"
    project_name        = var.project_name
    environment         = var.environment
    location            = var.location
    resource_group      = azurerm_resource_group.name.name
    subnet_ids          = [module.networking.subnet_ids["web"], module.networking.subnet_ids["app"], module.networking.subnet_ids["database"]]
    administrator_login = var.administrator_login
    administrator_password = var.administrator_password
    server_name         = module.database.server_name
    database_name       = module.database.database_name 
    server_id           = module.database.server_id
    database_id         = module.database.database_id
    user_assigned_identity_id = azurerm_user_assigned_identity.uai.id
    keyvault_name = module.security.keyvault_name
    user_assigned_identity_principal_id = azurerm_user_assigned_identity.uai.principal_id
    # user_assigned_identity_object_id = azurerm_user_assigned_identity.uai.object_id
    user_assigned_identity_tenant_id = azurerm_user_assigned_identity.uai.tenant_id
    # webapp_object_id = module.compute.webapp_object_id


    depends_on = [module.database]
}

module "networking" {
    source              = "../../modules/networking"
    project_name        = var.project_name
    environment         = var.environment
    location            = var.location
    subnet_prefixes = var.subnet_prefixes
    address_space       = var.address_space
    resource_group = azurerm_resource_group.name.name
    public_ip_id       = module.networking.public_ip_id
}

module "security" {
    source              = "../../modules/security"
    project_name        = var.project_name
    environment         = var.environment
    location            = var.location
    resource_group = azurerm_resource_group.name.name
    fqdn                = module.compute.fqdn
    subnet_prefixes     = var.subnet_prefixes
    public_ip_id        = module.networking.public_ip_id
    subnet_ids          = [module.networking.subnet_ids["web"], module.networking.subnet_ids["app"], module.networking.subnet_ids["database"], module.networking.subnet_ids["appgw"]]
    server_name         = module.database.server_name
    database_name       = module.database.database_name
    user_assigned_identity_id = azurerm_user_assigned_identity.uai.id
    user_assigned_identity_principal_id = azurerm_user_assigned_identity.uai.principal_id
    # user_assigned_identity_object_id = azurerm_user_assigned_identity.uai.object_id
    user_assigned_identity_tenant_id = azurerm_user_assigned_identity.uai.tenant_id
    # webapp_object_id = module.compute.webapp_object_id

    depends_on = [ module.networking]
}

module "database" {
    source              = "../../modules/database"
    project_name        = var.project_name
    environment         = var.environment
    location            = var.location
    resource_group_name = azurerm_resource_group.name.name
    subnet_ids          = [module.networking.subnet_ids["web"], module.networking.subnet_ids["app"], module.networking.subnet_ids["database"]]
    administrator_login = var.administrator_login
    administrator_password = var.administrator_password

}

module "monitoring" {
    source              = "../../modules/monitoring"
    project_name        = var.project_name
    environment         = var.environment
    location            = var.location
    resource_group_name = azurerm_resource_group.name.name
}



// create a private endpoint and dns zone for the sql server

resource "azurerm_private_endpoint" "pe-sql" {
    name                = "${var.project_name}-pe-sql-${var.environment}"
    location            = var.location
    resource_group_name = azurerm_resource_group.name.name
    subnet_id           = module.networking.subnet_ids["database"]

    private_service_connection {
        name                           = "${var.project_name}-psc-sql-${var.environment}"
        is_manual_connection            = false
        private_connection_resource_id  = module.database.server_id
        subresource_names               = ["sqlServer"]
    }

    private_dns_zone_group {
        name                 = "${var.project_name}-pdz-sql-${var.environment}"
        private_dns_zone_ids = [azurerm_private_dns_zone.sql_private_dns_zone.id]
    }
  
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_zone_link" {
    name                  = "${var.project_name}-dns-link-sql-${var.environment}"
    resource_group_name   = azurerm_resource_group.name.name
    private_dns_zone_name = azurerm_private_dns_zone.sql_private_dns_zone.name
    virtual_network_id    = module.networking.vnet_id
  
}

resource "azurerm_private_dns_zone" "sql_private_dns_zone" {
    name                = "privatelink.database.windows.net"
    resource_group_name = azurerm_resource_group.name.name

}


// create a private endpoint and dns zone for the web app

resource "azurerm_private_dns_zone" "webapp_private_dns_zone" {
    name                = "privatelink.azurewebsites.net"
    resource_group_name = azurerm_resource_group.name.name

}

resource "azurerm_private_endpoint" "pe-webapp" {
    name                = "${var.project_name}-pe-webapp-${var.environment}"
    location            = var.location
    resource_group_name = azurerm_resource_group.name.name
    subnet_id           = module.networking.subnet_ids["web"]

    private_service_connection {
        name                           = "${var.project_name}-psc-webapp-${var.environment}"
        is_manual_connection            = false
        private_connection_resource_id  = module.compute.webapp_id
        subresource_names               = ["sites"]
    }

    private_dns_zone_group {
        name                 = "${var.project_name}-pdz-webapp-${var.environment}"
        private_dns_zone_ids = [azurerm_private_dns_zone.webapp_private_dns_zone.id]
    }
}

resource "azurerm_private_dns_zone_virtual_network_link" "webapp_dns_zone_link" {
    name                  = "${var.project_name}-dns-link-webapp-${var.environment}"
    resource_group_name   = azurerm_resource_group.name.name
    private_dns_zone_name = azurerm_private_dns_zone.webapp_private_dns_zone.name
    virtual_network_id    = module.networking.vnet_id
  
}