moved {
  from = module.platform[0].azurerm_virtual_network.poc
  to   = module.network.azurerm_virtual_network.poc
}
moved {
  from = module.platform[0].azurerm_subnet.apim
  to   = module.network.azurerm_subnet.apim
}
moved {
  from = module.platform[0].azurerm_network_security_group.apim
  to   = module.network.azurerm_network_security_group.apim
}
moved {
  from = module.platform[0].azurerm_subnet_network_security_group_association.apim
  to   = module.network.azurerm_subnet_network_security_group_association.apim
}