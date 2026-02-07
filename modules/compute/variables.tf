variable "resource_group" {
    description = "The resource group where compute resources will be deployed."
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

variable "location" {
    description = "The Azure region for the resources."
    type        = string
}

variable "subnet_ids" {
    description = "A map of subnet IDs for the compute resources."
    type        = list(string)   
}


variable "server_name" {
    description = "The name of the SQL server to connect to."
    type        = string
}

variable "database_name" {
    description = "The name of the SQL database to connect to."
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



