
// Application Gateway with WAF

data "azurerm_client_config" "current" {
}

# data "azurerm_user_assigned_identity" "uai" {
#     name                = "${var.project_name}-identity-${var.environment}"
#     resource_group_name = var.resource_group
# }

resource "azurerm_application_gateway" "appgw" {
    name                = "${var.project_name}-appgw-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group
    identity {
        type = "UserAssigned"
        identity_ids = [var.user_assigned_identity_id]
    }

    firewall_policy_id = azurerm_web_application_firewall_policy.webafw.id

    sku {
        name     = "WAF_v2"
        tier     = "WAF_v2"
    }

    autoscale_configuration {
      min_capacity = 2
      max_capacity = 5
    }

    gateway_ip_configuration {
        name      = "appgw-ip-config"
        subnet_id = var.subnet_ids["0"]
    }

    frontend_port {
        name = "frontendPort"
        port = 80
    }

    frontend_ip_configuration {
        name                 = "appgw-frontend-ip"
        public_ip_address_id = var.public_ip_id
    }

    backend_address_pool {
        name = "appgw-backend-pool"
    }

    backend_http_settings {
        name                  = "appgw-backend-https-settings"
        cookie_based_affinity = "Disabled"
        port                  = 80
        protocol              = "Http"
        pick_host_name_from_backend_address = false
        probe_name            = "appgw-health-probe"
    }

    http_listener {
        name                           = "appgw-http-listener"
        frontend_ip_configuration_name = "appgw-frontend-ip"
        frontend_port_name             = "frontendPort"
        protocol                       = "Http"
    }

    request_routing_rule {
        name                       = "appgw-routing-rule"
        priority = 9
        rule_type                  = "Basic"
        http_listener_name         = "appgw-http-listener"
        backend_address_pool_name  = "appgw-backend-pool"
        backend_http_settings_name = "appgw-backend-https-settings"
    }

    probe {
        name                = "appgw-health-probe"
        protocol            = "Http"
        host                = "localhost"
        path                = "/"
        interval            = 30
        timeout             = 30
        unhealthy_threshold = 3
        pick_host_name_from_backend_http_settings = false
    }
}




// Web Application Firewall Policy

resource "azurerm_web_application_firewall_policy" "webafw" {
    name                = "${var.project_name}-wafpolicy-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group

   custom_rules {
    name      = "Rule1"
    priority  = 1
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["192.168.1.0/24", "10.0.0.0/24"]
    }

    action = "Block"
  }

  custom_rules {
    name      = "Rule2"
    priority  = 2
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["192.168.1.0/24"]
    }

    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "UserAgent"
      }

      operator           = "Contains"
      negation_condition = false
      match_values       = ["Windows"]
    }

    action = "Block"
  }

    policy_settings {
      enabled = true
      mode = "Prevention"
      request_body_check = true
     file_upload_limit_in_mb = 100
     max_request_body_size_in_kb = 128
    }

    managed_rules {

        exclusion {
      match_variable          = "RequestHeaderNames"
      selector                = "x-company-secret-header"
      selector_match_operator = "Equals"
    }
    exclusion {
      match_variable          = "RequestCookieNames"
      selector                = "too-tasty"
      selector_match_operator = "EndsWith"
    }
    managed_rule_set {
            type    = "OWASP"
            version = "3.2"
    rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rule {
          id      = "920300"
          enabled = true
          action  = "Log"
        }

        rule {
          id      = "920440"
          enabled = true
          action  = "Block"
        }
      }
        }
    }
  
}

// web Network Security Group

resource "azurerm_network_security_group" "web-nsg" {
    name                = "${var.project_name}-nsg-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group
}

// Security Rules
resource "azurerm_network_security_rule" "allow_http_inbound_web" {
    name                        = "Allow-https-Inbound-web"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "443"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name = var.resource_group
    network_security_group_name = azurerm_network_security_group.web-nsg.name
}

resource "azurerm_network_security_rule" "allow_appgw_management" {
    name                        = "Allow-AppGW-Management"
    priority                    = 200
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "65200-65535"
    source_address_prefix       = "GatewayManager"
    destination_address_prefix  = "*"
    resource_group_name         = var.resource_group
    network_security_group_name = azurerm_network_security_group.web-nsg.name
}


// app Network Security Group
resource "azurerm_network_security_group" "app-nsg" {
    name                = "${var.project_name}-app-nsg-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group
}

// Security Rules

resource "azurerm_network_security_rule" "allow_http_inbound_app" {
    name                        = "Allow-https-Inbound-app"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "443"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name = var.resource_group
    network_security_group_name = azurerm_network_security_group.app-nsg.name
}

resource "azurerm_network_security_rule" "allow_https_outbound_app" {
    name                        = "Allow-https-Outbound-app"
    priority                    = 110
    direction                   = "Outbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "443"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name = var.resource_group
    network_security_group_name = azurerm_network_security_group.app-nsg.name
  
}



// database Network Security Group
resource "azurerm_network_security_group" "data-nsg" {
    name                = "${var.project_name}-nsg-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group
}

resource "azurerm_network_security_rule" "allow_https_inbound_data" {
    name                        = "Allow-https-Inbound-data"
    priority                    = 110
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "443"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name = var.resource_group
    network_security_group_name = azurerm_network_security_group.data-nsg.name
}

resource "azurerm_network_security_rule" "allow_https_outbound_data" {
    name                        = "Allow-https-Outbound-data"
    priority                    = 110
    direction                   = "Outbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "443"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name = var.resource_group
    network_security_group_name = azurerm_network_security_group.data-nsg.name
}










// Associate NSG to Subnets
resource "azurerm_subnet_network_security_group_association" "web_nsg_association" {
    subnet_id                 = var.subnet_ids[0]
    network_security_group_id = azurerm_network_security_group.web-nsg.id
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_association" {
    subnet_id                 = var.subnet_ids[1]
    network_security_group_id = azurerm_network_security_group.app-nsg.id
}

resource "azurerm_subnet_network_security_group_association" "data_nsg_association" {
    subnet_id                 = var.subnet_ids[2]
    network_security_group_id = azurerm_network_security_group.data-nsg.id
}



 // create key vault for app service to access database credentials
    resource "azurerm_key_vault" "kv" {
        name                = "${var.project_name}-${var.environment}-kvbg"
        location            = var.location
        resource_group_name = var.resource_group
        tenant_id           = var.user_assigned_identity_tenant_id
        enabled_for_disk_encryption = true
        soft_delete_retention_days = 7
        purge_protection_enabled = true
        sku_name            = "standard"
        access_policy {
            tenant_id = var.user_assigned_identity_tenant_id
            object_id = var.user_assigned_identity_principal_id
    
            key_permissions = [
                "Get",
                "List",
                # "Set",
                # "Delete"
            ]
    
            secret_permissions = [
                "Get",
                "List",
                "Set",
                "Delete"
            ]
    
            storage_permissions = [
                "Get",
                "List",
                "Set",
                "Delete"
            ]
        }

        access_policy {
            tenant_id = data.azurerm_client_config.current.tenant_id
            object_id = data.azurerm_client_config.current.object_id

            secret_permissions = [
                "Get",
                "List",
                "Set",
                "Delete"
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






