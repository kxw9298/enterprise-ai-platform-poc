mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}
variables {
  subscription_id     = "11111111-1111-1111-1111-111111111111"
  publisher_email     = "operator@example.com"
  aks_admin_object_id = "22222222-2222-2222-2222-222222222222"
}
run "up_includes_platform" {
  command = plan
  assert {
    condition     = length(module.platform) == 1
    error_message = "The normal plan must include the platform."
  }
  assert {
    condition     = azurerm_resource_group.poc.name == "rg-ai-platform-poc"
    error_message = "The persistent resource group must keep its existing name."
  }
}
run "down_retains_foundation" {
  command = plan
  variables { enable_platform = false }
  assert {
    condition     = length(module.platform) == 0 && azurerm_resource_group.poc.name == "rg-ai-platform-poc"
    error_message = "Down must remove the whole platform module while retaining the group."
  }
}
