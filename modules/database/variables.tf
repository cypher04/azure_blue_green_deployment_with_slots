variable "resource_group_name" {
    description = "The name of the resource group."
    type        = string
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
variable "location" {
    description = "The Azure region for the resources."
    type        = string
}
variable "project_name" {
    description = "The name of the project."
    type        = string
}
variable "environment" {
    description = "The environment for the deployment (e.g., dev, prod)."
    type        = string
}
variable "subnet_ids" {
    description = "A map of subnet IDs for the database resources."
    type        = list(string)
}
