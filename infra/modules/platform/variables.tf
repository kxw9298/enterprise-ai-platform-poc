terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.7.0"
    }
  }
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "suffix" { type = string }
variable "tenant_id" { type = string }
variable "publisher_email" { type = string }
variable "aks_admin_object_id" { type = string }
variable "api_audience" { type = string }
variable "allowed_client_ids" { type = list(string) }
locals {
  name             = "aipoc-${var.suffix}"
  model_name       = "gpt-4.1-mini"
  model_version    = "2025-04-14"
  model_deployment = "poc-chat"
  mcp_ip           = "10.42.0.10"
}

variable "aks_node_size" { type = string }
