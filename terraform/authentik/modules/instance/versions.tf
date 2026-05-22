# Module: authentik/instance
#
# Composition module that bundles the full Authentik configuration (flows,
# branding, RBAC groups, app catalog, social auth sources, outpost, service
# accounts, notifications) into a single reusable unit. Used by both prod and
# staging env roots — each root passes its own provider configurations and the
# environment's domain.
#
# Note: the app catalog under apps.tf currently bundles the dciww-commons
# application set (Outline, Decidim, Nextcloud, etc.). If/when a second
# consumer onboards sabokit, the catalog should be extracted from
# this composition into the consumer repo and the module reduced to the
# generic Authentik bootstrap (flows, brand, RBAC, outpost, notifications).
# Leaf modules in this directory (oidc-app, saml-app, bookmark,
# traefik-forward-auth) are already generic and reused by the composition.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12.0"
    }
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
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
