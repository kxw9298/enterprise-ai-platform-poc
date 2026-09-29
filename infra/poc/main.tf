provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true

  features {
    # Disposable POC services: remove soft-deleted reservations on teardown.
    # Requires an administrator or explicitly delegated purge permissions.
    api_management {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = false
    }
    cognitive_account { purge_soft_delete_on_destroy = true }
    log_analytics_workspace { permanently_delete_on_destroy = true }
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

data "azurerm_client_config" "current" {}

module "platform" {
  count               = var.enable_platform ? 1 : 0
  source              = "../modules/platform"
  resource_group_name = azurerm_resource_group.poc.name
  location            = azurerm_resource_group.poc.location
  tags                = azurerm_resource_group.poc.tags
  suffix              = substr(sha256(var.subscription_id), 0, 8)
  tenant_id           = data.azurerm_client_config.current.tenant_id
  publisher_email     = var.publisher_email
  api_audience        = var.api_audience
  jump_ssh_public_key = var.jump_ssh_public_key
  jump_vm_size        = var.jump_vm_size
  enable_jump_egress  = var.enable_jump_egress
  requests_per_minute = var.requests_per_minute
  tokens_per_minute   = var.tokens_per_minute
  daily_token_quota   = var.daily_token_quota
}
