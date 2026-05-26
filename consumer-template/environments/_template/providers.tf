# Per-env provider config. Credentials are env-specific (different Scaleway
# project, different Authentik instance per env in most setups).

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scaleway  = { source = "scaleway/scaleway", version = ">= 2.7.0" }
    authentik = { source = "goauthentik/authentik", version = ">= 2024.6.0, < 2027.0.0" }
    random    = { source = "hashicorp/random", version = "~> 3.0" }
    time      = { source = "hashicorp/time", version = "~> 0.11" }
    tls       = { source = "hashicorp/tls", version = "~> 4.0" }
  }

  # Remote state. Run `terraform init -backend-config=backend.hcl` so the
  # backend's per-env values come from backend.hcl (not committed here).
  backend "s3" {
    region                      = "fr-par"
    endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    use_lockfile                = true
  }
}

# All Scaleway provider configuration is supplied via SCW_* environment
# variables exported by _lib.sh (credentials from the env, project/region/zone
# from config.tf). We deliberately leave this block empty so the provider
# sees exactly one credential source (env) instead of three (env +
# provider-block + ~/.config/scw/config.yaml active profile), which produces
# a noisy "Multiple variable sources detected" warning on every plan/apply.
provider "scaleway" {}

# Aliased provider used by platform/base/terraform for the gateway DNS A
# record. Most consumers share credentials with the main provider — leave
# both blocks empty and let _lib.sh's SCW_* exports drive both. Override
# below when your DNS zone lives in a different Scaleway project than the
# rest of your infra:
#
#   provider "scaleway" {
#     alias      = "dns"
#     access_key = var.scaleway_dns_access_key
#     secret_key = var.scaleway_dns_secret_key
#     project_id = var.scaleway_dns_project_id
#     region     = var.scaleway_region
#   }
provider "scaleway" {
  alias = "dns"
}

provider "authentik" {
  url   = "https://${local.config.gateway_domain}"
  token = var.authentik_admin_token
}
