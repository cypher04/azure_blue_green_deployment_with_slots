

resource "random_id" "server" {
    byte_length = 4

    keepers = {
      azi = 1
    }

}

resource "azurerm_virtual_network" "vnet" {
    name                = "${var.project_name}-vnet-${var.environment}"
    address_space       = var.address_space
    location            = var.location
    resource_group_name = var.resource_group
}

resource "azurerm_subnet" "web" {
    name                 = "${var.project_name}-subnet-web-${var.environment}"
    resource_group_name  = var.resource_group
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = [var.subnet_prefixes["web"]]
}

resource "azurerm_subnet" "app" {
    name                 = "${var.project_name}-subnet-app-${var.environment}"
    resource_group_name  = var.resource_group
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = [var.subnet_prefixes["app"]]
}

resource "azurerm_subnet" "database" {
    name                 = "${var.project_name}-subnet-database-${var.environment}"
    resource_group_name  = var.resource_group
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = [var.subnet_prefixes["database"]]
}


resource "azurerm_public_ip" "pip" {
  name                = "${var.project_name}-pip-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Static"
}


resource "azurerm_traffic_manager_profile" "traman" {
    name                = "${var.project_name}-traman-${var.environment}"
    resource_group_name = var.resource_group
    profile_status     = "Enabled"
    traffic_routing_method = "Priority"
    
    dns_config {
        relative_name = "${var.project_name}-tm-${var.environment}"
        ttl           = 100
    }
    
    monitor_config {
        protocol = "HTTPS"
        port     = 443
        path     = "/"
        interval_in_seconds = 30
        timeout_in_seconds  = 10
        tolerated_number_of_failures = 3
    }
}

resource "azurerm_traffic_manager_azure_endpoint" "tramanend" {
    name                = "${var.project_name}-traman-endpoint-${var.environment}"
    profile_id = azurerm_traffic_manager_profile.traman.id
    target_resource_id = var.public_ip_id
    always_serve_enabled = true
    weight = 100
}



