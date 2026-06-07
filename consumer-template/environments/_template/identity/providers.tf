terraform {
  required_version = ">= 1.10.0"

  required_providers {
    authentik = { source = "goauthentik/authentik", version = ">= 2024.6.0, < 2027.0.0" }
    scaleway  = { source = "scaleway/scaleway", version = ">= 2.7.0" }
    random    = { source = "hashicorp/random", version = "~> 3.0" }
    tls       = { source = "hashicorp/tls", version = "~> 4.0" }
  }

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

provider "scaleway" {}

# Minted by infra's Authentik bootstrap, fetched by the deploy scripts
# (terraform -chdir=../infra output authentik_admin_secret_id -> scw secret ->
# api_token) and exported as TF_VAR_authentik_admin_token before apply.
variable "authentik_admin_token" {
  description = "Authentik bootstrap admin API token (from the infra layer's authentik_admin_secret_id)."
  type        = string
  sensitive   = true
}

provider "authentik" {
  url   = "https://${local.env.identity_domain}"
  token = var.authentik_admin_token
}
