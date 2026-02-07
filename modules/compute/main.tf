

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
            "DATABASE_URL" = "Server=${var.server_name};Database=${var.database_name};User Id=${var.administrator_login};Password=${var.administrator_password};"
            "WEBSITES_PORT" = "3000"
        }

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
