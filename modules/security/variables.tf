variable "resource_group" {
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

variable "subnet_prefixes" {
    description = "A map of subnet names to their address prefixes."
    type        = map(string)
}

variable "public_ip_id" {
    description = "The ID of the public IP address."
    type        = string
}

variable "subnet_ids" {
    description = "The IDs of the subnets."
    type        = list(string)
}
