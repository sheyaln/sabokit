terraform {
  required_version = ">= 1.10.0"

  required_providers {
    scaleway  = { source = "scaleway/scaleway", version = ">= 2.7.0" }
    authentik = { source = "goauthentik/authentik", version = ">= 2024.6.0, < 2027.0.0" }
    random    = { source = "hashicorp/random", version = "~> 3.0" }
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

# Authentik admin token is read straight from the Scaleway secret that infra's
# Authentik bootstrap mints — no exporting TF_VAR_authentik_admin_token. A bare
# `terraform apply` needs only the SCW_*/AWS_* creds the backend + scaleway
# provider already use. The secret name is the infra bootstrap convention
# "<org_slug>-<env>-authentik-admin" (a key_value bag); we pull its api_token.
data "scaleway_secret" "authentik_admin" {
  name   = "${local.common.org_slug}-${local.env_name}-authentik-admin"
  region = local.env.scaleway_region
}

data "scaleway_secret_version" "authentik_admin" {
  secret_id = data.scaleway_secret.authentik_admin.id
  revision  = "latest"
  region    = local.env.scaleway_region
}

# Break-glass override only. Normally empty → the secret above is the source.
# Keeps existing TF_VAR_authentik_admin_token exports working (and avoids an
# "undeclared variable" warning) without making them required.
variable "authentik_admin_token" {
  description = "Optional override for the Authentik admin API token (TF_VAR_authentik_admin_token). Empty by default — the token is read from infra's Scaleway secret."
  type        = string
  sensitive   = true
  default     = ""
}

provider "authentik" {
  url = "https://${local.env.identity_domain}"
  token = var.authentik_admin_token != "" ? var.authentik_admin_token : jsondecode(
    base64decode(data.scaleway_secret_version.authentik_admin.data)
  )["api_token"]
}
