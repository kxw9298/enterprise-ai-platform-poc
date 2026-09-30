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
    virtual_network_rules { subnet_id = var.apim_subnet_id }
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

# Two secretless client IDs for direct gateway tests from the Bastion jump VM.
# Sharing this VM is a test harness, not isolation between untrusted tenants.
resource "azurerm_user_assigned_identity" "test_client" {
  for_each            = toset(["client-a", "client-b"])
  name                = "id-${local.name}-test-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "gateway_model" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = var.gateway_principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_api_management_api" "model" {
  name                  = "model"
  api_management_name   = var.gateway_name
  resource_group_name   = var.resource_group_name
  revision              = "1"
  display_name          = "POC model gateway"
  path                  = "models"
  protocols             = ["https"]
  subscription_required = false
  service_url           = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.openai.azure.com"
}
resource "azurerm_api_management_api_operation" "chat" {
  operation_id        = "chat"
  api_name            = azurerm_api_management_api.model.name
  api_management_name = var.gateway_name
  resource_group_name = var.resource_group_name
  display_name        = "Chat completion"
  method              = "POST"
  url_template        = "/chat/completions"
}
resource "azurerm_api_management_api_policy" "model" {
  api_name            = azurerm_api_management_api.model.name
  api_management_name = var.gateway_name
  resource_group_name = var.resource_group_name
  xml_content = templatefile("${path.module}/../platform/policies/model.xml.tftpl", {
    tenant_id           = var.tenant_id
    audience            = var.api_audience
    client_ids          = [for key in sort(keys(azurerm_user_assigned_identity.test_client)) : azurerm_user_assigned_identity.test_client[key].client_id]
    deployment          = local.model_deployment
    requests_per_minute = var.requests_per_minute
    tokens_per_minute   = var.tokens_per_minute
    daily_token_quota   = var.daily_token_quota
  })
  depends_on = [azurerm_role_assignment.gateway_model, azurerm_cognitive_deployment.chat]
}