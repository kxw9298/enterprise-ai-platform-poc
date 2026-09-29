resource "azurerm_virtual_network" "poc" {
  name                = "vnet-${local.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.42.0.0/16"]
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
