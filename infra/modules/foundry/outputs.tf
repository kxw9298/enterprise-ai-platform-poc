output "api_name" { value = azurerm_api_management_api.model.name }
output "deployment" { value = azurerm_cognitive_deployment.chat.name }
output "client_ids" { value = { for k, v in azurerm_user_assigned_identity.test_client : k => v.client_id } }

output "identity_ids" { value = [for v in azurerm_user_assigned_identity.test_client : v.id] }
