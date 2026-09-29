output "connection_details" {
  value = {
    # Deferred AKS/MCP connection details; restore after enabling the resources.
    # aks_name            = azurerm_kubernetes_cluster.poc.name
    # node_resource_group = azurerm_kubernetes_cluster.poc.node_resource_group
    # registry            = azurerm_container_registry.poc.login_server
    # mcp_path            = "/mcp/"
    # mcp_internal_ip     = local.mcp_ip
    # mcp_backend_port    = 8080
    # mcp_subnet          = azurerm_subnet.aks.name
    # runtime_client_ids  = { for k, v in azurerm_user_assigned_identity.mcp : k => v.client_id }

    jump_vm_name         = azurerm_linux_virtual_machine.jump.name
    jump_username        = azurerm_linux_virtual_machine.jump.admin_username
    region               = var.location
    bastion_sku          = azurerm_bastion_host.poc.sku
    apim_network_mode    = azurerm_api_management.poc.virtual_network_type
    admin_egress_enabled = var.enable_jump_egress
    bastion_name         = azurerm_bastion_host.poc.name
    gateway_private_ips  = azurerm_api_management.poc.private_ip_addresses
    gateway_url          = azurerm_api_management.poc.gateway_url
    model_path           = "/models/chat/completions"
    api_audience         = var.api_audience
    model                = local.model_name
    deployment           = azurerm_cognitive_deployment.chat.name
    workspace_id         = azurerm_log_analytics_workspace.poc.workspace_id
    test_client_ids      = { for k, v in azurerm_user_assigned_identity.test_client : k => v.client_id }
  }
}
