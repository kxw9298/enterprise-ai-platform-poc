resource "azurerm_api_management" "poc" {
  name                 = "apim-${local.name}"
  resource_group_name  = var.resource_group_name
  location             = var.location
  publisher_name       = "Enterprise AI POC"
  publisher_email      = var.publisher_email
  sku_name             = "Developer_1"
  virtual_network_type = "Internal"
  virtual_network_configuration { subnet_id = var.apim_subnet_id }
  identity { type = "SystemAssigned" }
  tags = var.tags
  timeouts {
    create = "120m"
    update = "120m"
    delete = "120m"
  }
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
resource "azurerm_api_management_api_diagnostic" "poc" {
  for_each                  = merge({ mcp = azurerm_api_management_api.mcp.name }, var.enable_foundry ? { model = module.foundry[0].api_name } : {})
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
resource "azurerm_api_management_api" "mcp" {
  name                  = "mcp"
  api_management_name   = azurerm_api_management.poc.name
  resource_group_name   = var.resource_group_name
  revision              = "1"
  display_name          = "Private MCP"
  path                  = "mcp"
  protocols             = ["https"]
  subscription_required = false
  service_url           = var.mcp_backend_url
}
resource "azurerm_api_management_api_operation" "mcp" {
  for_each            = toset(["GET", "POST", "DELETE"])
  operation_id        = lower(each.key)
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = azurerm_api_management.poc.name
  resource_group_name = var.resource_group_name
  display_name        = "MCP ${each.key}"
  method              = each.key
  url_template        = "/"
}
resource "azurerm_api_management_api_policy" "mcp" {
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = azurerm_api_management.poc.name
  resource_group_name = var.resource_group_name
  xml_content = templatefile("${path.module}/policies/mcp.xml.tftpl", {
    tenant_id     = var.tenant_id
    audience      = var.api_audience
    client_ids    = var.allowed_client_ids
    backend_ready = var.mcp_backend_ready
  })
}

# Minimal private-network probe. It has no backend so it isolates Power Platform
# private connectivity from container, AKS, registry and model provisioning.
resource "azurerm_api_management_api" "connectivity" {
  name                = "connectivity"
  api_management_name = azurerm_api_management.poc.name
  resource_group_name = var.resource_group_name
  revision            = "1"
  display_name        = "Private Connectivity Probe"
  path                = "connectivity"
  protocols           = ["https"]
  # The endpoint is already reachable only through the internal APIM gateway.
  # Keep the first network probe keyless so Copilot Studio can test connectivity
  # without introducing a secret into the connector configuration.
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "connectivity" {
  operation_id        = "get-connectivity"
  api_name            = azurerm_api_management_api.connectivity.name
  api_management_name = azurerm_api_management.poc.name
  resource_group_name = var.resource_group_name
  display_name        = "Get connectivity status"
  method              = "GET"
  url_template        = "/"
  response {
    status_code = 200
    description = "Private connectivity probe response"
    representation { content_type = "application/json" }
  }
}

resource "azurerm_api_management_api_policy" "connectivity" {
  api_name            = azurerm_api_management_api.connectivity.name
  api_management_name = azurerm_api_management.poc.name
  resource_group_name = var.resource_group_name
  xml_content         = file("${path.module}/policies/connectivity.xml")
}
