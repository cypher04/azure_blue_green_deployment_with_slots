output "app_gateway_id" {
    value = azurerm_application_gateway.appgw
}

output "nsg_ids" {
    value = [azurerm_network_security_group.web-nsg.id, azurerm_network_security_group.app-nsg.id, azurerm_network_security_group.data-nsg.id]
}

output "firewall_id" {
    value = azurerm_web_application_firewall_policy.webafw.id
}


# output "uai_client_id" {
#     value = data.azurerm_user_assigned_identity.uai.client_id   
# }

# output "uai_principal_id" {
#     value = data.azurerm_user_assigned_identity.uai.principal_id   
# }

# output "uai_tenant_id" {
#     value = data.azurerm_user_assigned_identity.uai.tenant_id
# }
