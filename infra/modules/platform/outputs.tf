output "connection_details" {
  value = {
    aks_name            = azurerm_kubernetes_cluster.poc.name
    node_resource_group = azurerm_kubernetes_cluster.poc.node_resource_group
    registry            = azurerm_container_registry.poc.login_server
    gateway_url         = azurerm_api_management.poc.gateway_url
    model_path          = "/models/chat/completions"
    mcp_path            = "/mcp/"
    mcp_internal_ip     = local.mcp_ip
    mcp_backend_port    = 8080
    mcp_subnet          = azurerm_subnet.aks.name
    api_audience        = var.api_audience
    model               = local.model_name
    deployment          = azurerm_cognitive_deployment.chat.name
    workspace_id        = azurerm_log_analytics_workspace.poc.workspace_id
    runtime_client_ids  = { for k, v in azurerm_user_assigned_identity.mcp : k => v.client_id }
  }
}
