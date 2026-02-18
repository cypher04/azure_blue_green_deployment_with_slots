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
    subnet_prefixes     = var.subnet_prefixes
    public_ip_id        = module.networking.public_ip_id
    subnet_ids          = [module.networking.subnet_ids["web"], module.networking.subnet_ids["app"], module.networking.subnet_ids["database"]]
    server_name         = module.database.server_name
    database_name       = module.database.database_name
    user_assigned_identity_id = azurerm_user_assigned_identity.uai.id
    webapp_tenant_id = module.compute.webapp_tenant_id
    webapp_principal_id = module.compute.webapp_principal_id

    depends_on = [ module.networking ]
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