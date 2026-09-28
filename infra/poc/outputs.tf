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
