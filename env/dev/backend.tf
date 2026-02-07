// backend configuration for Terraform state
terraform {
  backend "azurerm" {
    resource_group_name  = "myprojectdev-bg-rg"
    storage_account_name = "myprojectstatedev-bg"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}