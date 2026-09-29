resource "azurerm_api_management" "poc" {
  name                 = "apim-${local.name}"
  resource_group_name  = var.resource_group_name
  location             = var.location
  publisher_name       = "Enterprise AI POC"
  publisher_email      = var.publisher_email
  sku_name             = "Developer_1"
  virtual_network_type = "Internal"
  virtual_network_configuration { subnet_id = azurerm_subnet.apim.id }
  identity { type = "SystemAssigned" }
  tags = var.tags
  timeouts {
    create = "120m"
    update = "120m"
    delete = "120m"
  }
  depends_on = [azurerm_subnet_network_security_group_association.apim]
}
resource "azurerm_role_assignment" "gateway_model" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_api_management.poc.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "gateway_metrics" {
  scope                = azurerm_application_insights.poc.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_api_management.poc.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_api_management_logger" "poc" {
  name                = "appinsights"
  api_management_name = azurerm_api_management.poc.name
  resource_group_name = var.resource_group_name
  resource_id         = azurerm_application_insights.poc.id
  application_insights {
    connection_string  = azurerm_application_insights.poc.connection_string
    identity_client_id = "SystemAssigned"
  }
  depends_on = [azurerm_role_assignment.gateway_metrics]
}
resource "azurerm_api_management_api" "model" {
  name                  = "model"
  api_management_name   = azurerm_api_management.poc.name
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
  api_management_name = azurerm_api_management.poc.name
  resource_group_name = var.resource_group_name
  display_name        = "Chat completion"
  method              = "POST"
  url_template        = "/chat/completions"
}
resource "azurerm_api_management_api_policy" "model" {
  api_name            = azurerm_api_management_api.model.name
  api_management_name = azurerm_api_management.poc.name
  resource_group_name = var.resource_group_name
  xml_content = templatefile("${path.module}/policies/model.xml.tftpl", {
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
resource "azurerm_api_management_api_diagnostic" "poc" {
  for_each                  = { model = azurerm_api_management_api.model.name }
  identifier                = "applicationinsights"
  api_name                  = each.value
  api_management_name       = azurerm_api_management.poc.name
  resource_group_name       = var.resource_group_name
  api_management_logger_id  = azurerm_api_management_logger.poc.id
  sampling_percentage       = 100
  always_log_errors         = true
  log_client_ip             = false
  http_correlation_protocol = "W3C"
  verbosity                 = "information"
  frontend_request { body_bytes = 0 }
  frontend_response { body_bytes = 0 }
  backend_request { body_bytes = 0 }
  backend_response { body_bytes = 0 }
}
