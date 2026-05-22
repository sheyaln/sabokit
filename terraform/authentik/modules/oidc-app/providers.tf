terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = ">= 2025.6.0"
    }
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
