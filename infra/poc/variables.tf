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

variable "api_audience" {
  description = "Expected token audience for the Entra model API registration; configure before endpoint testing."
  type        = string
  default     = "api://enterprise-ai-platform-poc"
  validation {
    condition     = can(regex("^(api://[A-Za-z0-9._/-]+|[a-fA-F0-9-]{36})$", var.api_audience))
    error_message = "Use the API application UUID for v2 tokens or its api:// URI for v1 tokens."
  }
}

variable "jump_ssh_public_key" {
  description = "SSH public key for Bastion access to the jump VM. Never pass the private key."
  type        = string
  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa) [A-Za-z0-9+/=]+", trimspace(var.jump_ssh_public_key)))
    error_message = "Provide an OpenSSH public key, not a private key."
  }
}

variable "jump_vm_size" {
  description = "Independent admin VM size; use a smaller burstable SKU after checking subscription availability."
  type        = string
  default     = "Standard_D2s_v7"
}
variable "enable_jump_egress" {
  description = "Optional paid NAT gateway for jump VM Internet access and package installation. Off for short internal-only tests."
  type        = bool
  default     = false
}

variable "requests_per_minute" {
  type        = number
  default     = 10
  description = "Per authenticated client request rate."
  validation {
    condition     = var.requests_per_minute > 0 && floor(var.requests_per_minute) == var.requests_per_minute
    error_message = "Use a positive integer."
  }
}

variable "tokens_per_minute" {
  type        = number
  default     = 1000
  description = "Per authenticated client prompt/completion token rate."
  validation {
    condition     = var.tokens_per_minute > 0 && floor(var.tokens_per_minute) == var.tokens_per_minute
    error_message = "Use a positive integer."
  }
}

variable "daily_token_quota" {
  type        = number
  default     = 10000
  description = "Per authenticated client daily token quota; not an exact dollar cap."
  validation {
    condition     = var.daily_token_quota > 0 && floor(var.daily_token_quota) == var.daily_token_quota
    error_message = "Use a positive integer."
  }
}
