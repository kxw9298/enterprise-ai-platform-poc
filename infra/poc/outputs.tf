output "resource_group_name" {
  description = "The Terraform-managed POC resource group."
  value       = azurerm_resource_group.poc.name
}

output "resource_group_id" {
  description = "Scope for the subsequent pipeline Contributor assignment."
  value       = azurerm_resource_group.poc.id
}
