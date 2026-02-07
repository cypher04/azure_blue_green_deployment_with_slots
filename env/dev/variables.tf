variable "project_name" {
    description = "The name of the project."
    type        = string
}

variable "resource_group" {
    description = "The name of the resource group."
    type        = string     
}

variable "environment" {
    description = "The environment for the deployment (e.g., dev, prod)."
    type        = string
}

variable "subscription_id" {
    description = "The subscription ID for the Azure resources."
    type        = string
}

variable "location" {
    description = "The Azure region for the resources."
    type        = string
    default     = "East US"
}

variable "address_space" {
    description = "The address space for the virtual network."
    type        = list(string)
}

variable "subnet_prefixes" {
    description = "A map of subnet names to their address prefixes."
    type        = map(string)
}

variable "administrator_login" {
    description = "The administrator login for the SQL server."
    type        = string
}
variable "administrator_password" {
    description = "The administrator password for the SQL server."
    type        = string
    sensitive   = true
}

variable "server_name" {
    description = "The name of the SQL server."
    type        = string
}

variable "database_name" {
    description = "The name of the SQL database."
    type        = string
}

