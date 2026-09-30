output "backend_url" { value = "https://${local.hostname}" }
output "environment_name" { value = azurerm_container_app_environment.poc.name }
output "private_ingress" { value = azurerm_container_app_environment.poc.internal_load_balancer_enabled }
output "app_deployed" { value = length(azurerm_container_app.mcp) == 1 }
output "app_name" { value = local.app_name }
