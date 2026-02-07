output "resource_group_name" {
    value = azurerm_resource_group.name.name
}

output "location" {
    value = azurerm_resource_group.name.location
}

output "environment" {
    value = var.environment
}

output "subnet_prefixes" {
    value = var.subnet_prefixes
}

output "subnet_ids" {
  value = module.networking
}

output "public_ip_id" {
  value = module.networking.public_ip_id
}
