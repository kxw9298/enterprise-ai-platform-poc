# Retained optional local module; no Foundry resources when disabled.
module "foundry" {
  count                = var.enable_foundry ? 1 : 0
  source               = "../foundry"
  resource_group_name  = var.resource_group_name
  location             = var.location
  tags                 = var.tags
  suffix               = var.suffix
  tenant_id            = var.tenant_id
  api_audience         = var.api_audience
  apim_subnet_id       = var.apim_subnet_id
  gateway_name         = azurerm_api_management.poc.name
  gateway_principal_id = azurerm_api_management.poc.identity[0].principal_id
  requests_per_minute  = var.requests_per_minute
  tokens_per_minute    = var.tokens_per_minute
  daily_token_quota    = var.daily_token_quota
}
