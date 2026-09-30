output "aks_name" { value = azurerm_kubernetes_cluster.poc.name }
output "registry" { value = var.registry_server }
