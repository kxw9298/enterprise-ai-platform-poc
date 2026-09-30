mock_provider "azapi" {}
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
    condition     = module.platform[0].connection_details.apim_network_mode == "Internal" && length(module.admin_access) == 0 && !module.platform[0].connection_details.foundry_enabled
    error_message = "APIM must stay internal; Foundry and admin compute must be off by default."
  }
  assert {
    condition     = length(module.mcp_runtime) == 1 && var.aks_node_size == "Standard_D4s_v7" && !var.enable_jump_egress
    error_message = "Use the minimum-size four-vCPU AKS SKU and no paid admin NAT gateway by default."
  }
}
run "down_retains_foundation" {
  command = plan
  variables { enable_platform = false }
  assert {
    condition     = length(module.platform) == 0 && length(module.mcp_runtime) == 0 && length(module.admin_access) == 0 && length(module.network.dns_vnet_ids) == 4
    error_message = "Down must remove the whole platform module while retaining the group."
  }
}

run "foundry_can_be_enabled" {
  command = plan
  variables { enable_foundry = true }
  assert {
    condition     = module.platform[0].connection_details.foundry_enabled
    error_message = "Foundry must be available without uncommenting resources."
  }
}

run "optional_admin_and_foundry" {
  command = plan
  variables {
    enable_foundry      = true
    enable_admin_access = true
  }
  assert {
    condition     = length(module.admin_access) == 1 && module.platform[0].connection_details.foundry_enabled
    error_message = "Optional admin and Foundry modules must remain compatible."
  }
}
