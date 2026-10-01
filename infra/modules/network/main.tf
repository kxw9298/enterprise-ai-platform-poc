resource "azurerm_virtual_network" "poc" {
  name                = "vnet-${local.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.42.0.0/21"]
  tags                = var.tags
}
resource "azurerm_subnet" "apim" {
  name                 = "snet-apim"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.poc.name
  address_prefixes     = ["10.42.4.0/27"]
  dynamic "service_endpoint" {
    for_each = toset(["Microsoft.Storage", "Microsoft.Sql", "Microsoft.AzureActiveDirectory", "Microsoft.CognitiveServices"])
    content { service = service_endpoint.value }
  }
}
resource "azurerm_network_security_group" "apim" {
  name                = "nsg-${local.name}-apim"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  security_rule {
    name                       = "GatewayHttps"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "ApimControlPlane"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "LoadBalancerHealth"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6390"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }
}
resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}


locals {
  regions = {
    eastus = { vnet = "10.43.0.0/26", subnet = "10.43.0.0/26" }
    westus = { vnet = "10.44.0.0/26", subnet = "10.44.0.0/26" }
  }
}
resource "azurerm_virtual_network" "integration" {
  for_each            = local.regions
  name                = "vnet-ai-poc-powerplatform-${each.key}"
  resource_group_name = var.resource_group_name
  location            = each.key
  address_space       = [each.value.vnet]
  tags                = var.tags
}
resource "azurerm_subnet" "delegated" {
  for_each             = local.regions
  name                 = "snet-powerplatform"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.integration[each.key].name
  address_prefixes     = [each.value.subnet]
  delegation {
    name = "powerplatform"
    service_delegation {
      name    = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
resource "azapi_resource" "network_policy" {
  type      = "Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview"
  name      = "ep-ai-poc-network"
  parent_id = var.resource_group_id
  location  = "unitedstates"
  tags      = var.tags
  body = {
    kind = "NetworkInjection"
    properties = {
      networkInjection = {
        virtualNetworks = [for region in sort(keys(local.regions)) : {
          id     = azurerm_virtual_network.integration[region].id
          subnet = { name = azurerm_subnet.delegated[region].name }
        }]
      }
    }
  }
}

resource "azurerm_virtual_network" "aks" {
  name                = "vnet-${local.name}-aks"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.45.0.0/24"]
  tags                = var.tags
}
resource "azurerm_subnet" "aks" {
  name                            = "snet-aks"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.aks.name
  address_prefixes                = ["10.45.0.0/26"]
  default_outbound_access_enabled = false
}
locals {
  # for_each keys must be provably static, so derive them from local.regions and a
  # literal, never from resource attributes. Deriving them from apply-time values
  # breaks `terraform import` and forces a two-step targeted apply.
  spoke_keys  = concat(["aks"], sort(keys(local.regions)))
  spokes      = { for k in local.spoke_keys : k => k == "aks" ? azurerm_virtual_network.aks.id : azurerm_virtual_network.integration[k].id }
  spoke_names = { for k in local.spoke_keys : k => k == "aks" ? azurerm_virtual_network.aks.name : azurerm_virtual_network.integration[k].name }
}
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each                     = local.spokes
  name                         = "hub-to-${each.key}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.poc.name
  remote_virtual_network_id    = each.value
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each                     = local.spokes
  name                         = "${each.key}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = local.spoke_names[each.key]
  remote_virtual_network_id    = azurerm_virtual_network.poc.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Separate delegated subnet; the reserved AKS subnet remains for phase 2.
resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["10.45.0.64/27"]
  delegation {
    name = "container-apps"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
