mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}
variables {
  jump_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOUVMJ5Iza0gmpoUdWKVHi/NsDLUiCtrIW8q6yBsuEpo poc-jump"
  subscription_id     = "11111111-1111-1111-1111-111111111111"
  publisher_email     = "operator@example.com"
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
run "private_access_and_cost_defaults" {
  command = plan
  assert {
    condition     = module.platform[0].connection_details.apim_network_mode == "Internal" && module.platform[0].connection_details.bastion_sku == "Basic"
    error_message = "APIM must stay internal and Bastion must not default to a premium tier."
  }
  assert {
    condition     = module.platform[0].connection_details.region == "eastus" && !module.platform[0].connection_details.admin_egress_enabled
    error_message = "Keep one region and no paid admin NAT gateway by default."
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
