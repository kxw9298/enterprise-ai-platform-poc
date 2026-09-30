terraform {
  required_providers { azurerm = { source = "hashicorp/azurerm", version = "= 5.7.0" } }
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "suffix" { type = string }
variable "tags" { type = map(string) }
resource "azurerm_container_registry" "poc" {
  name                = "craipoc${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}
output "id" { value = azurerm_container_registry.poc.id }
output "name" { value = azurerm_container_registry.poc.name }
output "login_server" { value = azurerm_container_registry.poc.login_server }
