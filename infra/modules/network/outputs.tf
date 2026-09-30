output "hub_name" { value = azurerm_virtual_network.poc.name }
output "apim_subnet_id" { value = azurerm_subnet.apim.id }
output "aks_subnet_id" { value = azurerm_subnet.aks.id }
output "aks_vnet_id" { value = azurerm_virtual_network.aks.id }
output "dns_vnet_ids" { value = merge({ hub = azurerm_virtual_network.poc.id }, local.spokes) }
output "enterprise_policy_id" { value = azapi_resource.network_policy.id }
