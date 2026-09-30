output "resource_group_name" {
  description = "The Terraform-managed POC resource group."
  value       = azurerm_resource_group.poc.name
}

output "resource_group_id" {
  description = "Scope for the subsequent pipeline Contributor assignment."
  value       = azurerm_resource_group.poc.id
}

output "platform" {
  description = "Non-secret endpoints and identity IDs; null when the platform is down."
  value       = var.enable_platform ? module.platform[0].connection_details : null
}

output "enterprise_policy_id" { value = module.network.enterprise_policy_id }
output "mcp_runtime" { value = var.enable_platform && var.enable_mcp_runtime ? { aks_name = module.mcp_runtime[0].aks_name, registry = module.mcp_runtime[0].registry } : null }
