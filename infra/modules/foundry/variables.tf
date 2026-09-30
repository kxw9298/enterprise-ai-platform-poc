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
variable "apim_subnet_id" { type = string }
variable "gateway_principal_id" { type = string }
variable "gateway_name" { type = string }
variable "requests_per_minute" { type = number }
variable "tokens_per_minute" { type = number }
variable "daily_token_quota" { type = number }
locals {
  model_name       = "gpt-4.1-mini"
  model_version    = "2025-04-14"
  model_deployment = "poc-chat"
}
