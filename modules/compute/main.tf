

resource "azurerm_service_plan" "serveplan" {
    name                = "${var.project_name}-asp-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group
    os_type = "Linux"
    sku_name = "P1v2"
    }




    resource "azurerm_linux_web_app" "webapp" {
      name                = "${var.project_name}-webapp-${var.environment}"
      location            = var.location
      resource_group_name = var.resource_group
      service_plan_id     = azurerm_service_plan.serveplan.id
      client_certificate_enabled = true
      client_certificate_mode = "Required"


      identity {
        type = "SystemAssigned"
      }
      auth_settings {
        enabled = true
        unauthenticated_client_action = "RedirectToLoginPage"
      }

      site_config {}

        app_settings = {
            "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
            "DATABASE_URL" = "Server=@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.mssql-server-name.id});Database=@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.mssql-database-name.id});User Id=${var.administrator_login};Password=${var.administrator_password};"
            "WEBSITES_PORT" = "3000"
        }

    }

    // role assignment for app service to access mssql server
    resource "azurerm_role_assignment" "appservice_mssql_access" {
      scope                = azurerm_mssql_server.mssqlsrv.id
      role_definition_name = "Contributor"
      principal_id         = azurerm_linux_web_app.webapp.identity.principal_id
    }

    resource "azurerm_linux_web_app_slot" "blue" {
      name                = "${var.project_name}-webapp-staging-${var.environment}"
      app_service_id   = azurerm_linux_web_app.webapp.id
      auth_settings {
        enabled = true
        unauthenticated_client_action = "RedirectToLoginPage"
      }

      site_config {

      }
    }



    resource "azurerm_linux_web_app_slot" "green" {
      name                = "${var.project_name}-webapp-staging2-${var.environment}"
      app_service_id   = azurerm_linux_web_app.webapp.id
      auth_settings {
        enabled = true
        unauthenticated_client_action = "RedirectToLoginPage"
      }
      
      site_config {

      }

    
    }


    resource "azurerm_web_app_active_slot" "acive_slot" {
      slot_id =     azurerm_linux_web_app_slot.blue.id
    }

    

   resource "azurerm_app_service_virtual_network_swift_connection" "asvnet-conn-webapp" {
    app_service_id = azurerm_linux_web_app.webapp.id
    subnet_id      = var.subnet_ids["1"]
}

    resource "azurerm_app_service_slot_virtual_network_swift_connection" "asvnet-conn-blue" {
      
      slot_name = azurerm_linux_web_app_slot.blue.name
      app_service_id = azurerm_linux_web_app_slot.blue.id
      subnet_id           = var.subnet_ids["1"]

    }

    resource "azurerm_app_service_slot_virtual_network_swift_connection" "asvnet-conn-green" {
      
      slot_name = azurerm_linux_web_app_slot.green.name
      app_service_id = azurerm_linux_web_app_slot.green.id
      subnet_id           = var.subnet_ids["1"]

    }


     // create key vault for app service to access database credentials
    resource "azurerm_key_vault" "kv" {
        name                = "${var.project_name}-${var.environment}-kv"
        location            = var.location
        resource_group_name = var.resource_group.name
        tenant_id           = azurerm_linux_web_app.webapp.identity[0].tenant_id
        enabled_for_disk_encryption = true
        soft_delete_retention_days = 7
        purge_protection_enabled = true
        sku_name            = "standard"
        access_policy {
            tenant_id = azurerm_linux_web_app.webapp.identity[0].tenant_id
            object_id = azurerm_linux_web_app.webapp.identity[0].principal_id
    
            key_permissions = [
                "get",
                "list",
                "set",
                "delete"
            ]
    
            secret_permissions = [
                "get",
                "list",
                "set",
                "delete"
            ]
    
            storage_permissions = [
                "get",
                "list",
                "set",
                "delete"
            ]
        }
    }
    
    resource "azurerm_key_vault_secret" "mssql_database_name" {
        name         = "mssql-database-name"
        value        = var.database_name
        key_vault_id = azurerm_key_vault.kv.id
    }

    resource "azurerm_key_vault_secret" "mssql_server_name" {
        name         = "mssql-server-name"
        value        = var.server_name
        key_vault_id = azurerm_key_vault.kv.id
    }
