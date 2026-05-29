terraform {
  required_version = ">= 1.7.0"

  required_providers {
    # Default (unaliased) providers, inherited from the calling layer root.
    # No scaleway.dns alias: this module reads existing resources, it never
    # touches DNS — which is also why it validates standalone (no
    # configuration_aliases to satisfy with a wrapper).
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.7.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12.0"
    }
  }
}
