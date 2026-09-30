# Exact gateway FQDN only: never shadow the public azure-api.net parent zone.
resource "azurerm_private_dns_zone" "gateway" {
  name                = "${azurerm_api_management.poc.name}.azure-api.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "gateway" {
  for_each             = var.dns_vnet_ids
  name                 = "poc-${each.key}"
  private_dns_zone_id  = azurerm_private_dns_zone.gateway.id
  virtual_network_id   = each.value
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
