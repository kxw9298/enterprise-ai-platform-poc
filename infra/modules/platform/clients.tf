# Two secretless client IDs for direct gateway tests from the Bastion jump VM.
# Sharing this VM is a test harness, not isolation between untrusted tenants.
resource "azurerm_user_assigned_identity" "test_client" {
  for_each            = toset(["client-a", "client-b"])
  name                = "id-${local.name}-test-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
