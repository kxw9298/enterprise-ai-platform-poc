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

locals { suffix = substr(sha256(var.subscription_id), 0, 8) }
provider "azapi" { subscription_id = var.subscription_id }
module "network" {
  source              = "../modules/network"
  resource_group_name = azurerm_resource_group.poc.name
  resource_group_id   = azurerm_resource_group.poc.id
  location            = azurerm_resource_group.poc.location
  tags                = azurerm_resource_group.poc.tags
  suffix              = local.suffix
}
module "platform" {
  count               = var.enable_platform ? 1 : 0
  source              = "../modules/platform"
  resource_group_name = azurerm_resource_group.poc.name
  location            = azurerm_resource_group.poc.location
  tags                = azurerm_resource_group.poc.tags
  suffix              = local.suffix
  tenant_id           = data.azurerm_client_config.current.tenant_id
  publisher_email     = var.publisher_email
  api_audience        = var.api_audience
  apim_subnet_id      = module.network.apim_subnet_id
  dns_vnet_ids        = module.network.dns_vnet_ids
  enable_foundry      = var.enable_foundry
  allowed_client_ids  = var.allowed_client_ids
  requests_per_minute = var.requests_per_minute
  tokens_per_minute   = var.tokens_per_minute
  daily_token_quota   = var.daily_token_quota
  depends_on          = [module.network]
}
module "mcp_runtime" {
  count               = var.enable_platform && var.enable_mcp_runtime ? 1 : 0
  source              = "../modules/mcp-runtime"
  resource_group_name = azurerm_resource_group.poc.name
  location            = azurerm_resource_group.poc.location
  tags                = azurerm_resource_group.poc.tags
  suffix              = local.suffix
  tenant_id           = data.azurerm_client_config.current.tenant_id
  aks_subnet_id       = module.network.aks_subnet_id
  aks_vnet_id         = module.network.aks_vnet_id
  aks_admin_object_id = var.aks_admin_object_id
  aks_node_size       = var.aks_node_size
}
module "admin_access" {
  count               = var.enable_platform && var.enable_admin_access ? 1 : 0
  source              = "../modules/admin-access"
  resource_group_name = azurerm_resource_group.poc.name
  location            = azurerm_resource_group.poc.location
  tags                = azurerm_resource_group.poc.tags
  suffix              = local.suffix
  test_identity_ids   = module.platform[0].test_identity_ids
  hub_vnet_name       = module.network.hub_name
  jump_ssh_public_key = var.jump_ssh_public_key
  jump_vm_size        = var.jump_vm_size
  enable_jump_egress  = var.enable_jump_egress
}
