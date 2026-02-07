
// Application Gateway with WAF

resource "azurerm_application_gateway" "appgw" {
    name                = "${var.project_name}-appgw-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group
    identity {
        type = "SystemAssigned"
    }

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
        port                  = 443
        protocol              = "Https"
        pick_host_name_from_backend_address = false
        probe_name            = "appgw-health-probe"
    }

    http_listener {
        name                           = "appgw-http-listener"
        frontend_ip_configuration_name = "appgw-frontend-ip"
        frontend_port_name             = "frontendPort"
        protocol                       = "Https"
    }

    request_routing_rule {
        name                       = "appgw-routing-rule"
        rule_type                  = "Basic"
        http_listener_name         = "appgw-http-listener"
        backend_address_pool_name  = "appgw-backend-pool"
        backend_http_settings_name = "appgw-backend-http-settings"
    }

    probe {
        name                = "appgw-health-probe"
        protocol            = "Https"
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
    name                = "${var.project_name}-waf-policy-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group

    custom_rules {
        name      = "BlockBadBots"
        priority  = 1
        rule_type = "MatchRule"

        match_conditions {
            match_variables {
                variable_name = "RemoteAddr"
                selector      = "RemoteAddr"
            }
            operator           = "Contains"
            match_values       = ["BadBot"]
            negation_condition = false
            transforms         = []
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
        managed_rule_set {
            type    = "OWASP"
            version = "3.2"
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








