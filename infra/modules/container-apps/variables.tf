terraform {
  required_providers { azurerm = { source = "hashicorp/azurerm", version = "= 5.7.0" } }
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "suffix" { type = string }
variable "tags" { type = map(string) }
variable "subnet_id" { type = string }
variable "dns_vnet_ids" { type = map(string) }
variable "workspace_id" { type = string }
variable "registry_id" { type = string }
variable "registry_server" { type = string }
variable "image_digest" { type = string }
locals {
  name     = "aipoc-${var.suffix}"
  app_name = "mcp-${local.name}"
  hostname = "${local.app_name}.${azurerm_container_app_environment.poc.default_domain}"
}
