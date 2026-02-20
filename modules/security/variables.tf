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

variable "server_name" {
    description = "The name of the SQL server to connect to."
    type        = string
}

variable "database_name" {
    description = "The name of the SQL database to connect to."
    type        = string
}

variable "user_assigned_identity_id" {
    description = "The ID of the user assigned identity."
    type        = string
}

variable "user_assigned_identity_tenant_id" {
    description = "The tenant ID of the user assigned identity."
    type        = string
}

variable "user_assigned_identity_principal_id" {
    description = "The principal ID of the user assigned identity."
    type        = string
}

# variable "user_assigned_identity_object_id" {
#     description = "The object ID of the user assigned identity."
#     type        = string
# }


# variable "webapp_tenant_id" {
#     description = "The tenant ID of the web app's managed identity."
#     type        = string
# }

# variable "webapp_principal_id" {
#     description = "The principal ID of the web app's managed identity."
#     type        = string
# }

# variable "webapp_object_id" {
#     description = "The object ID of the web app's managed identity."
#     type        = string
# }