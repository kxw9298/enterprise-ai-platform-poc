terraform {
  required_version = "= 1.16.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.7.0"
    }
  }

  # Names are supplied at init; authentication comes from the CLI or OIDC env.
  backend "azurerm" {
    use_azuread_auth = true
  }
}
