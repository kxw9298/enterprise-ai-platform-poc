terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "= 5.7.0" }
  }
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "suffix" { type = string }
locals { name = "aipoc-${var.suffix}" }
variable "tenant_id" { type = string }
variable "aks_subnet_id" { type = string }
variable "aks_vnet_id" { type = string }
variable "aks_admin_object_id" { type = string }
variable "aks_node_size" { type = string }
variable "registry_id" { type = string }
variable "registry_server" { type = string }
