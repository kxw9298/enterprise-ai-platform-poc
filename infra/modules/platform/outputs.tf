output "connection_details" {
  value = {
    gateway_url         = azurerm_api_management.poc.gateway_url
    gateway_private_ips = azurerm_api_management.poc.private_ip_addresses
    apim_network_mode   = azurerm_api_management.poc.virtual_network_type
    mcp_path            = "/mcp/"
    mcp_internal_ip     = local.mcp_ip
    workspace_id        = azurerm_log_analytics_workspace.poc.workspace_id
    foundry_enabled     = var.enable_foundry
    deployment          = try(module.foundry[0].deployment, null)
    test_client_ids     = try(module.foundry[0].client_ids, {})
  }
}

output "test_identity_ids" { value = try(module.foundry[0].identity_ids, []) }
