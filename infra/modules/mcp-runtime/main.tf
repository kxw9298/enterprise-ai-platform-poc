resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${local.name}-aks"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "id-${local.name}-kubelet"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_role_assignment" "aks_network" {
  scope                = var.aks_vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "kubelet_operator" {
  scope                = azurerm_user_assigned_identity.kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}
# Shared ACR is owned by ../registry for both runtime phases.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.kubelet.principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_kubernetes_cluster" "poc" {
  name                              = "aks-${local.name}"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  dns_prefix                        = "aks-${local.name}"
  node_resource_group               = "rg-${local.name}-nodes"
  sku_tier                          = "Free"
  local_account_disabled            = true
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  private_cluster_enabled           = true
  run_command_enabled               = false
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"
  node_provisioning_profile { mode = "Manual" }
  default_node_pool {
    name                        = "system"
    vm_size                     = var.aks_node_size
    node_count                  = 2
    vnet_subnet_id              = var.aks_subnet_id
    os_disk_size_gb             = 32
    os_disk_type                = "Managed"
    os_sku                      = "Ubuntu"
    max_pods                    = 30
    node_public_ip_enabled      = false
    temporary_name_for_rotation = "systemtmp"
    upgrade_settings { max_surge = "1" }
    tags = var.tags
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }
  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }
  azure_active_directory_role_based_access_control {
    tenant_id          = var.tenant_id
    azure_rbac_enabled = true
  }
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "10.244.0.0/22"
    service_cidr        = "10.250.0.0/24"
    dns_service_ip      = "10.250.0.10"
    outbound_type       = "loadBalancer"
    load_balancer_sku   = "standard"
    load_balancer_profile { managed_outbound_ip_count = 1 }
  }
  tags       = var.tags
  depends_on = [azurerm_role_assignment.aks_network, azurerm_role_assignment.kubelet_operator]
}
resource "azurerm_role_assignment" "aks_admin" {
  count                = var.aks_admin_object_id == null ? 0 : 1
  scope                = azurerm_kubernetes_cluster.poc.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.aks_admin_object_id
}
