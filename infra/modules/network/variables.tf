terraform {
  required_providers {
    azapi   = { source = "Azure/azapi", version = "~> 2.0" }
    azurerm = { source = "hashicorp/azurerm", version = "= 5.7.0" }
  }
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "suffix" { type = string }
locals { name = "aipoc-${var.suffix}" }

variable "resource_group_id" { type = string }
