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

provider "scaleway" {
  access_key = var.scaleway_access_key
  secret_key = var.scaleway_secret_key
  region     = var.scaleway_region
  zone       = var.scaleway_zone
  project_id = var.scaleway_project_id
}

provider "authentik" {
  url   = "https://${var.gateway_domain}"
  token = var.authentik_admin_token
}
