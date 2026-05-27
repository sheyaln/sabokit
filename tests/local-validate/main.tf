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
  required_version = ">= 1.7.0"
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
  org_name       = "Sabokit Test"
  org_slug       = "sabokittest"
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

module "privacy_policy" {
  source = "../../platform/apps/privacy-policy/terraform"

  enabled  = true
  hostname = "privacy.example.org"
  base     = local.base
}

module "nextcloud" {
  source = "../../platform/apps/nextcloud/terraform"

  enabled             = true
  hostname            = "cloud.example.org"
  onlyoffice_hostname = "docs.example.org"
  talk_hostname       = "talk.example.org"
  base                = local.base
}

module "decidim" {
  source = "../../platform/apps/decidim/terraform"

  enabled            = true
  hostname           = "voting.example.org"
  organization_name  = "Example Assembly"
  system_admin_email = "ops@example.org"
  base               = local.base
}

module "jitsi" {
  source = "../../platform/apps/jitsi/terraform"

  enabled  = true
  hostname = "meet.example.org"
  base     = local.base
}

module "espocrm" {
  source = "../../platform/apps/espocrm/terraform"

  enabled  = true
  hostname = "crm.example.org"
  base     = local.base
}

module "n8n" {
  source = "../../platform/apps/n8n/terraform"

  enabled  = true
  hostname = "automate.example.org"
  base     = local.base
}

module "backrest_mgmt" {
  source = "../../platform/apps/backrest/terraform"

  enabled             = true
  hostname            = "backup.mgmt.example.org"
  instance_name       = "mgmt"
  deployment_host_key = "apps"
  backup_plans = [
    {
      id       = "daily"
      paths    = ["/backup-sources/opt"]
      schedule = { cron = "0 3 * * *" }
      retention = {
        hourly  = 24
        daily   = 7
        weekly  = 4
        monthly = 12
        yearly  = 3
      }
    },
  ]
  base = local.base
}

module "autoheal_apps" {
  source              = "../../platform/apps/autoheal/terraform"
  enabled             = true
  deployment_host_key = "apps"
  base                = local.base
}

module "diun_mgmt" {
  source              = "../../platform/apps/diun/terraform"
  enabled             = true
  instance_name       = "apps"
  deployment_host_key = "apps"
  base                = local.base
}

module "prometheus" {
  source              = "../../platform/core/prometheus/terraform"
  enabled             = true
  deployment_host_key = "apps"
  base                = local.base
}

module "loki" {
  source              = "../../platform/core/loki/terraform"
  enabled             = true
  deployment_host_key = "apps"
  base                = local.base
}

module "grafana" {
  source              = "../../platform/core/grafana/terraform"
  enabled             = true
  hostname            = "grafana.example.org"
  deployment_host_key = "apps"
  base                = local.base
}

module "wazuh" {
  source              = "../../platform/core/wazuh/terraform"
  enabled             = true
  hostname            = "wazuh.example.org"
  deployment_host_key = "apps"
  base                = local.base
}

module "wazuh_agent_apps" {
  source               = "../../platform/apps/wazuh-agent/terraform"
  enabled              = true
  deployment_host_key  = "apps"
  manager_address      = "10.0.0.10"
  fim_enabled          = true
  fim_extra_paths      = ["/opt/custom-app/conf"]
  fim_extra_exclusions = ["/opt/custom-app/conf/cache"]
  base                 = local.base
}
