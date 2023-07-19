# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.64.0"
    }
  }

  required_version = ">= 1.1.0"

  backend "azurerm" {
    resource_group_name  = "ScDc-CIO-DTO-Infrastructure-rg"
    storage_account_name = "scdcinfrastructure"
    container_name       = "tfstate"
    key                  = "chatbot.pilot.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
        prevent_deletion_if_contains_resources = false
    }
  }
}
