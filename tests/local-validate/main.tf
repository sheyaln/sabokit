# End-to-end terraform validate harness. Wires platform/base/terraform +
# platform/identity/terraform + every shipping app bundle together with
# relative paths to catch type mismatches in CI without needing real Scaleway
# credentials.
#
# Use:
#   cd tests/local-validate
#   terraform init -backend=false
#   terraform validate
#
# Not intended for `apply` — providers are configured with dummy credentials.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    scaleway  = { source = "scaleway/scaleway", version = ">= 2.7.0" }
    authentik = { source = "goauthentik/authentik", version = ">= 2024.6.0, < 2027.0.0" }
    random    = { source = "hashicorp/random", version = "~> 3.0" }
    time      = { source = "hashicorp/time", version = "~> 0.11" }
    tls       = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "scaleway" {
  access_key = "SCWTEST"
  secret_key = "00000000-0000-0000-0000-000000000000"
  project_id = "00000000-0000-0000-0000-000000000000"
  region     = "fr-par"
  zone       = "fr-par-1"
}

# Aliased provider for DNS — same creds as the main provider in this harness.
# Real consumers override with separate credentials when their DNS zone lives
# in a different Scaleway project from the deploy project.
provider "scaleway" {
  alias      = "dns"
  access_key = "SCWTEST"
  secret_key = "00000000-0000-0000-0000-000000000000"
  project_id = "00000000-0000-0000-0000-000000000000"
  region     = "fr-par"
  zone       = "fr-par-1"
}

provider "authentik" {
  url      = "https://auth.example.org"
  token    = "test-token"
  insecure = true
}

module "base" {
  source = "../../platform/base/terraform"
  providers = {
    scaleway     = scaleway
    scaleway.dns = scaleway.dns
  }

  scaleway_project_id    = "00000000-0000-0000-0000-000000000000"
  org_slug               = "fctest"
  environment            = "dev"
  base_domain            = "example.org"
  gateway_domain         = "auth.example.org"
  private_network_subnet = "10.0.0.0/22"

  compute_hosts = {
    apps = {
      instance_type = "DEV1-S"
      role          = "apps"
      ansible_group = "apps"
    }
  }
}

module "identity_bootstrap" {
  source = "../../platform/identity/bootstrap"

  org_slug    = "fctest"
  environment = "dev"
  infra_email = "ops@example.org"

  postgres_instance_id = module.base.scaleway.postgres_instance_id
  postgres_endpoint    = module.base.scaleway.postgres_endpoint
  postgres_engine      = module.base.scaleway.postgres_engine
}

module "authentik" {
  source = "../../platform/identity/terraform"

  gateway_domain = module.base.domains.gateway_domain
  base_domain    = module.base.domains.base_domain
  org_name       = "Federated Commons Test"
  org_slug       = "fctest"
  infra_email    = "ops@example.org"
}

locals {
  base = {
    scaleway  = module.base.scaleway
    compute   = module.base.compute
    domains   = module.base.domains
    authentik = module.authentik.authentik
  }
}

module "outline" {
  source = "../../platform/apps/outline/terraform"

  enabled  = true
  hostname = "wiki.example.org"
  base     = local.base
}

module "steward" {
  source = "../../platform/apps/steward/terraform"

  enabled  = true
  hostname = "members.example.org"
  base     = local.base
}

module "vikunja" {
  source = "../../platform/apps/vikunja/terraform"

  enabled  = true
  hostname = "tasks.example.org"
  base     = local.base
}

module "bentopdf" {
  source = "../../platform/apps/bentopdf/terraform"

  enabled  = true
  hostname = "pdf.example.org"
  base     = local.base
}

module "notifuse" {
  source = "../../platform/apps/notifuse/terraform"

  enabled          = true
  hostname         = "email.example.org"
  root_admin_email = "ops@example.org"
  smtp_from_email  = "notify@example.org"
  base             = local.base
}
