output "app_gateway_id" {
    value = azurerm_application_gateway.appgw
}

output "nsg_ids" {
    value = [azurerm_network_security_group.web-nsg.id, azurerm_network_security_group.app-nsg.id, azurerm_network_security_group.data-nsg.id]
}

output "firewall_id" {
    value = azurerm_web_application_firewall_policy.webafw.id
}
