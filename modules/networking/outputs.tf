output "subnet_ids" {
    value = {
        web      = azurerm_subnet.web.id
        app      = azurerm_subnet.app.id
        database = azurerm_subnet.database.id
    }
}

output "public_ip_id" {
    value = azurerm_public_ip.pip.id
}

output "public_ip" {
    value = azurerm_public_ip.pip.ip_address
}


