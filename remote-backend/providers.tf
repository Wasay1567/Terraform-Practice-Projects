terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.57.0"
    }
  }
  backend "azurerm" {
      resource_group_name  = "practice"
      storage_account_name = "tf17723"
      container_name       = "tfstate"
      key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "fef39593-b8e1-484e-9ffe-e8ce32dc8a33"
  features {}
}