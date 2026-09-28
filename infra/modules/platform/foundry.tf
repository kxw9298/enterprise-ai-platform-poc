resource "azurerm_cognitive_account" "foundry" {
  name                          = "ai-${local.name}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "AIServices"
  sku_name                      = "S0"
  custom_subdomain_name         = "ai-${local.name}"
  project_management_enabled    = true
  local_auth_enabled            = false
  public_network_access_enabled = true
  network_acls {
    default_action = "Deny"
    virtual_network_rules { subnet_id = azurerm_subnet.apim.id }
  }
  identity { type = "SystemAssigned" }
  tags = var.tags
}
resource "azurerm_cognitive_account_project" "poc" {
  name                 = "enterprise-ai-poc"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  location             = var.location
  display_name         = "Enterprise AI POC"
  identity { type = "SystemAssigned" }
  tags = var.tags
}
resource "azurerm_cognitive_account_rai_policy" "poc" {
  name                 = "poc-content-filter"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  base_policy_name     = "Microsoft.Default"
  mode                 = "Blocking"
  dynamic "content_filter" {
    for_each = setproduct(["Hate", "Sexual", "Violence", "Selfharm"], ["Prompt", "Completion"])
    content {
      name               = content_filter.value[0]
      source             = content_filter.value[1]
      filter_enabled     = true
      block_enabled      = true
      severity_threshold = "Medium"
    }
  }
}
resource "azurerm_cognitive_deployment" "chat" {
  name                 = local.model_deployment
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  model {
    format  = "OpenAI"
    name    = local.model_name
    version = local.model_version
  }
  sku {
    name     = "GlobalStandard"
    capacity = 1
  }
  rai_policy_name        = azurerm_cognitive_account_rai_policy.poc.name
  version_upgrade_option = "NoAutoUpgrade"
}
