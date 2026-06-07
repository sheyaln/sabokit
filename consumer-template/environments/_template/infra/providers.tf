terraform {
  # >= 1.10: the S3 backend uses use_lockfile (native state locking).
  required_version = ">= 1.10.0"

  required_providers {
    scaleway = { source = "scaleway/scaleway", version = ">= 2.7.0" }
    random   = { source = "hashicorp/random", version = "~> 3.0" }
    time     = { source = "hashicorp/time", version = "~> 0.11" }
  }

  # Per-layer remote state. `terraform init -backend-config=backend.hcl`.
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

# Authenticates from SCW_ACCESS_KEY / SCW_SECRET_KEY in the environment. Left
# empty so the provider sees exactly one credential source (env) — project/
# region/zone reach resources through the module inputs (local.env.*).
provider "scaleway" {}

# Gateway DNS A record. Same creds as the main provider by default; declare
# credentials here only when your DNS zone lives in a different Scaleway
# project than the rest of your infra.
provider "scaleway" {
  alias = "dns"
}
