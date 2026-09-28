resource "azurerm_log_analytics_workspace" "poc" {
  name                = "log-${local.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags                = var.tags
}
resource "azurerm_application_insights" "poc" {
  name                         = "appi-${local.name}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  workspace_id                 = azurerm_log_analytics_workspace.poc.id
  application_type             = "web"
  sampling_percentage          = 100
  daily_data_cap_in_gb         = 1
  local_authentication_enabled = false
  tags                         = var.tags
}
