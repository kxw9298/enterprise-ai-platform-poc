# Superseded by infra/poc module.network. Do not initialize/apply this retired root.
# terraform {
#   required_version = "= 1.16.4"
#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "= 5.7.0"
#     }
#     azapi = {
#       source  = "Azure/azapi"
#       version = "~> 2.0"
#     }
#   }
#   # Dedicated state; never use poc.tfstate for this root.
#   backend "azurerm" {
#     use_azuread_auth = true
#     key              = "power-platform.tfstate"
#   }
# }
# provider "azurerm" {
#   subscription_id                 = var.subscription_id
#   resource_provider_registrations = "none"
#   features {}
# }
# provider "azapi" {
#   subscription_id = var.subscription_id
# }
# variable "subscription_id" { type = string }
# locals {
#   environment_id = "Default-eb241c67-e72d-4862-ae41-7686706624c4"
#   regions = {
#     eastus = { vnet = "10.43.0.0/16", subnet = "10.43.0.0/24" }
#     westus = { vnet = "10.44.0.0/16", subnet = "10.44.0.0/24" }
#   }
#   tags = { project = "enterprise-ai-platform-poc", purpose = "power-platform-integration" }
# }
# resource "azurerm_resource_group" "integration" {
#   name     = "rg-ai-platform-powerplatform"
#   location = "eastus"
#   tags     = local.tags
# }
# resource "azurerm_virtual_network" "integration" {
#   for_each            = local.regions
#   name                = "vnet-ai-poc-powerplatform-${each.key}"
#   resource_group_name = azurerm_resource_group.integration.name
#   location            = each.key
#   address_space       = [each.value.vnet]
#   tags                = local.tags
# }
# resource "azurerm_subnet" "delegated" {
#   for_each             = local.regions
#   name                 = "snet-powerplatform"
#   resource_group_name  = azurerm_resource_group.integration.name
#   virtual_network_name = azurerm_virtual_network.integration[each.key].name
#   address_prefixes     = [each.value.subnet]
#   delegation {
#     name = "powerplatform"
#     service_delegation {
#       name    = "Microsoft.PowerPlatform/enterprisePolicies"
#       actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
#     }
#   }
# }
# resource "azapi_resource" "network_policy" {
#   type      = "Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview"
#   name      = "ep-ai-poc-network"
#   parent_id = azurerm_resource_group.integration.id
#   location  = "unitedstates"
#   tags      = local.tags
#   body = {
#     kind = "NetworkInjection"
#     properties = {
#       networkInjection = {
#         virtualNetworks = [for region in sort(keys(local.regions)) : {
#           id     = azurerm_virtual_network.integration[region].id
#           subnet = { name = azurerm_subnet.delegated[region].name }
#         }]
#       }
#     }
#   }
# }
# output "environment_id" { value = local.environment_id }
# output "enterprise_policy_id" { value = azapi_resource.network_policy.id }
# output "integration_vnet_ids" {
#   value = { for region, vnet in azurerm_virtual_network.integration : region => vnet.id }
# }
