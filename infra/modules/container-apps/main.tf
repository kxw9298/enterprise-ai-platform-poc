resource "azurerm_container_app_environment" "poc" {
  name                               = "cae-${local.name}"
  resource_group_name                = var.resource_group_name
  location                           = var.location
  infrastructure_subnet_id           = var.subnet_id
  infrastructure_resource_group_name = "rg-${local.name}-container-managed"
  internal_load_balancer_enabled     = true
  public_network_access              = "Disabled"
  logs_destination                   = "log-analytics"
  log_analytics_workspace_id         = var.workspace_id
  zone_redundancy_enabled            = false
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
  tags = var.tags
}
resource "azurerm_user_assigned_identity" "image_pull" {
  name                = "id-${local.name}-container-pull"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_role_assignment" "image_pull" {
  scope                = var.registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.image_pull.principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_private_dns_zone" "environment" {
  name                = azurerm_container_app_environment.poc.default_domain
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_private_dns_a_record" "environment" {
  for_each            = toset(["@", "*"])
  name                = each.value
  private_dns_zone_id = azurerm_private_dns_zone.environment.id
  ttl                 = 300
  records             = [azurerm_container_app_environment.poc.static_ip_address]
  tags                = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "environment" {
  for_each             = var.dns_vnet_ids
  name                 = "container-${each.key}"
  private_dns_zone_id  = azurerm_private_dns_zone.environment.id
  virtual_network_id   = each.value
  registration_enabled = false
  tags                 = var.tags
}
# First apply provisions the registry/environment; image workflow then produces a digest.
# No placeholder image is presented as a working MCP service.
resource "azurerm_container_app" "mcp" {
  count                        = var.image_digest == "" ? 0 : 1
  name                         = local.app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.poc.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.image_pull.id]
  }
  registry {
    server   = var.registry_server
    identity = azurerm_user_assigned_identity.image_pull.id
  }
  template {
    min_replicas = 0
    max_replicas = 1
    container {
      name   = "mcp"
      image  = "${var.registry_server}/mcp-connectivity@${var.image_digest}"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name  = "MCP_ALLOWED_HOST"
        value = local.hostname
      }
      env {
        name  = "MCP_BUILD"
        value = var.image_digest
      }
      readiness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/healthz"
      }
      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/healthz"
      }
    }
    http_scale_rule {
      name                = "http"
      concurrent_requests = "10"
    }
  }
  ingress {
    # External to the environment, not public: the environment is internal-only.
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8080
    transport                  = "http"
    ip_security_restriction {
      name             = "apim-only"
      action           = "Allow"
      ip_address_range = "10.42.4.0/27"
      description      = "Only the internal APIM subnet may invoke MCP."
    }
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  tags       = var.tags
  depends_on = [azurerm_role_assignment.image_pull]
}
