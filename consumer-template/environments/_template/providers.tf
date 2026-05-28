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

# Scaleway provider authenticates from SCW_ACCESS_KEY / SCW_SECRET_KEY in the
# environment (exported via .envrc, or by sabokit-cli). The block is left empty
# on purpose so the provider sees exactly one credential source (env) instead
# of three (env + provider-block + ~/.config/scw/config.yaml active profile),
# which otherwise emits a noisy "Multiple variable sources detected" warning on
# every plan/apply. project_id/region/zone reach resources through the stack
# module's inputs (local.env.*), not this provider block.
provider "scaleway" {}

# Aliased provider used by platform/base/terraform for the gateway DNS A
# record. Most consumers share credentials with the main provider — leave both
# blocks empty and let the SCW_* env exports drive both. Override below when
# your DNS zone lives in a different Scaleway project than the rest of your
# infra (declare the referenced secret vars yourself):
#
#   provider "scaleway" {
#     alias      = "dns"
#     access_key = var.scaleway_dns_access_key
#     secret_key = var.scaleway_dns_secret_key
#     project_id = var.scaleway_dns_project_id
#     region     = local.env.scaleway_region
#   }
provider "scaleway" {
  alias = "dns"
}

provider "authentik" {
  url   = "https://${local.env.identity_domain}"
  token = var.authentik_admin_token
}
