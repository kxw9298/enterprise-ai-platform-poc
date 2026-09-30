output "aks_name" { value = azurerm_kubernetes_cluster.poc.name }
output "registry" { value = azurerm_container_registry.poc.login_server }
