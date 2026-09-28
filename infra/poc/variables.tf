variable "subscription_id" {
  description = "Azure subscription ID, supplied through TF_VAR_subscription_id."
  type        = string

  validation {
    condition     = can(regex("^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$", var.subscription_id))
    error_message = "subscription_id must be an Azure subscription UUID."
  }
}
