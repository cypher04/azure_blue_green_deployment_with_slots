variable "resource_group_name" {
    description = "The name of the resource group."
    type        = string    
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

