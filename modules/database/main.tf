resource "azurerm_mssql_server" "mssqlsrv" {
    name                         = "${var.project_name}-mssqlsrv-${var.environment}"
    resource_group_name          = var.resource_group_name
    location                     = var.location
    version                      = "12.0"
    administrator_login          = var.administrator_login
    administrator_login_password = var.administrator_password
    minimum_tls_version = "1.2"
    public_network_access_enabled = false


    identity {
        type = "SystemAssigned"
    }

    tags = {
        environment = var.environment
        project     = var.project_name
    }
}


resource "azurerm_mssql_database" "mssqldb" {
    name                = "${var.project_name}-mssqldb-${var.environment}"
    server_id           = azurerm_mssql_server.mssqlsrv.id
    collation = "SQL_Latin1_General_CP1_CI_AS"
    license_type = "BasePrice"
    enclave_type = "VBS"
    sku_name            = "S0"
    max_size_gb        = 10

    tags = {
        environment = var.environment
        project     = var.project_name
    }

    lifecycle {
      prevent_destroy = true
    }
}

resource "azurerm_mssql_virtual_network_rule" "name" {
    name                = "${var.project_name}-vnetrule-${var.environment}"
    server_id           = azurerm_mssql_server.mssqlsrv.id
    subnet_id           = var.subnet_ids[2]
}


