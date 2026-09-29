# Bastion brokers SSH to a private VM; API requests originate on that VM.
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.poc.name
  address_prefixes     = ["10.42.6.0/26"]
}
resource "azurerm_subnet" "jump" {
  name                            = "snet-admin"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.poc.name
  address_prefixes                = ["10.42.5.0/27"]
  default_outbound_access_enabled = false
}
resource "azurerm_public_ip" "bastion" {
  name                = "pip-${local.name}-bastion"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
resource "azurerm_bastion_host" "poc" {
  name                = "bas-${local.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  ip_configuration {
    name                 = "bastion"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
  tags = var.tags
}
# Optional outbound access for patching, CLI installation and Entra login.
# Off by default to avoid an idle NAT gateway charge during short test sessions.
# The VM still has no inbound public IP. This is not an egress firewall.
resource "azurerm_public_ip" "admin_egress" {
  count               = var.enable_jump_egress ? 1 : 0
  name                = "pip-${local.name}-admin-egress"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
resource "azurerm_nat_gateway" "admin" {
  count               = var.enable_jump_egress ? 1 : 0
  name                = "nat-${local.name}-admin"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Standard"
  tags                = var.tags
}
resource "azurerm_nat_gateway_public_ip_association" "admin" {
  count                = var.enable_jump_egress ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.admin[0].id
  public_ip_address_id = azurerm_public_ip.admin_egress[0].id
}
resource "azurerm_subnet_nat_gateway_association" "admin" {
  count          = var.enable_jump_egress ? 1 : 0
  subnet_id      = azurerm_subnet.jump.id
  nat_gateway_id = azurerm_nat_gateway.admin[0].id
}
resource "azurerm_network_security_group" "jump" {
  name                = "nsg-${local.name}-admin"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  security_rule {
    name                       = "SshFromBastionOnly"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.bastion.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "DenyOtherInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "jump" {
  subnet_id                 = azurerm_subnet.jump.id
  network_security_group_id = azurerm_network_security_group.jump.id
}
resource "azurerm_network_interface" "jump" {
  name                = "nic-${local.name}-admin"
  resource_group_name = var.resource_group_name
  location            = var.location
  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.jump.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = var.tags
}
resource "azurerm_linux_virtual_machine" "jump" {
  name                = "vm-${local.name}-admin"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.jump_vm_size
  identity {
    type         = "UserAssigned"
    identity_ids = [for client in azurerm_user_assigned_identity.test_client : client.id]
  }
  admin_username                  = "pocadmin"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.jump.id]
  admin_ssh_key {
    username   = "pocadmin"
    public_key = var.jump_ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 32
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  custom_data = var.enable_jump_egress ? base64encode("#cloud-config\npackage_update: true\npackages:\n  - curl\n  - jq\n  - dnsutils\n") : null
  tags        = var.tags
  depends_on  = [azurerm_subnet_network_security_group_association.jump, azurerm_subnet_nat_gateway_association.admin, azurerm_nat_gateway_public_ip_association.admin]
}
# Exact gateway FQDN only: never shadow the public azure-api.net parent zone.
resource "azurerm_private_dns_zone" "gateway" {
  name                = "${azurerm_api_management.poc.name}.azure-api.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "gateway" {
  name                 = "poc-vnet"
  private_dns_zone_id  = azurerm_private_dns_zone.gateway.id
  virtual_network_id   = azurerm_virtual_network.poc.id
  registration_enabled = false
  tags                 = var.tags
}
resource "azurerm_private_dns_a_record" "gateway" {
  name                = "@"
  private_dns_zone_id = azurerm_private_dns_zone.gateway.id
  ttl                 = 300
  records             = azurerm_api_management.poc.private_ip_addresses
  tags                = var.tags
}
