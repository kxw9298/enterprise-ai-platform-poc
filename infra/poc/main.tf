provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

resource "azurerm_resource_group" "poc" {
  name     = "rg-ai-platform-poc"
  location = "eastus"

  tags = {
    project      = "enterprise-ai-platform-poc"
    environment  = "poc"
    "managed-by" = "terraform"
  }
}
