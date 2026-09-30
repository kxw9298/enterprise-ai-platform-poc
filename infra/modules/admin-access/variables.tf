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
variable "hub_vnet_name" { type = string }
variable "jump_ssh_public_key" { type = string }
variable "jump_vm_size" { type = string }
variable "enable_jump_egress" { type = bool }
variable "test_identity_ids" { type = list(string) }
