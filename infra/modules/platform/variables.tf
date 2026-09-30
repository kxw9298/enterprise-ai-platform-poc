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
variable "api_audience" { type = string }
variable "publisher_email" { type = string }
variable "apim_subnet_id" { type = string }
variable "dns_vnet_ids" { type = map(string) }
variable "enable_foundry" { type = bool }
variable "allowed_client_ids" { type = list(string) }
variable "requests_per_minute" { type = number }
variable "tokens_per_minute" { type = number }
variable "daily_token_quota" { type = number }

variable "mcp_backend_url" { type = string }
variable "mcp_backend_ready" { type = bool }
