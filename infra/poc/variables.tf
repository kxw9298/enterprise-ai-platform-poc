variable "subscription_id" {
  description = "Azure subscription ID, supplied through TF_VAR_subscription_id."
  type        = string

  validation {
    condition     = can(regex("^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$", var.subscription_id))
    error_message = "subscription_id must be an Azure subscription UUID."
  }
}

variable "enable_platform" {
  description = "False removes paid platform resources but retains the POC group and external bootstrap."
  type        = bool
  default     = true
}

variable "publisher_email" {
  description = "APIM publisher contact; provide via TF_VAR_publisher_email, never a credential."
  type        = string
  validation {
    condition     = can(regex("^[^@]+@[^@]+[.][^@]+$", var.publisher_email))
    error_message = "Provide a valid publisher email."
  }
}

variable "aks_admin_object_id" {
  description = "Entra object ID of the operator granted AKS RBAC Cluster Admin."
  type        = string
  validation {
    condition     = can(regex("^[a-fA-F0-9-]{36}$", var.aks_admin_object_id))
    error_message = "Provide the administrator object UUID."
  }
}

variable "api_audience" {
  description = "Audience of the future Entra API registration; APIs deny all external clients until allowed below."
  type        = string
  default     = "api://enterprise-ai-platform-poc"
  validation {
    condition     = can(regex("^api://[A-Za-z0-9._/-]+$", var.api_audience))
    error_message = "Use an api:// application URI without XML metacharacters."
  }
}

variable "allowed_client_ids" {
  description = "Explicit Entra application client IDs allowed to call MCP; empty means deny all."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for id in var.allowed_client_ids : can(regex("^[a-fA-F0-9-]{36}$", id))])
    error_message = "Client IDs must be UUIDs."
  }
}

variable "aks_node_size" {
  description = "CPU system node SKU. Recheck subscription restrictions and core quota before apply."
  type        = string
  default     = "Standard_D2s_v7"
}
