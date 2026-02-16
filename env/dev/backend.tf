// backend configuration for Terraform state
terraform {
  backend "azurerm" {
    resource_group_name  = "myprojectdev-bg-rg"
    storage_account_name = "myprojectstatedevbg"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}