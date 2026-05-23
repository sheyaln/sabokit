terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.7.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = ">= 2024.6.0, < 2027.0.0"
    }
  }
}
