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
variable "api_audience" { type = string }
locals {
  name             = "aipoc-${var.suffix}"
  model_name       = "gpt-4.1-mini"
  model_version    = "2025-04-14"
  model_deployment = "poc-chat"
}


variable "jump_ssh_public_key" { type = string }

variable "jump_vm_size" { type = string }
variable "enable_jump_egress" { type = bool }

variable "requests_per_minute" { type = number }
variable "tokens_per_minute" { type = number }
variable "daily_token_quota" { type = number }

# Deferred: enable with the AKS/MCP milestone, then review and run a new plan.
# variable "aks_admin_object_id" { type = string }
# variable "allowed_client_ids" { type = list(string) }
# variable "aks_node_size" { type = string }
# locals { mcp_ip = "10.42.0.10" }
