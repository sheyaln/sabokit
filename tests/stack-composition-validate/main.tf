# Composition-layer validation harness. Exercises `consumer-template/modules/stack/`
# end-to-end against the current working tree — NOT a previously-tagged release.
#
# The fixture in `tests/local-validate/` validates platform BUNDLES in
# isolation (module "base", module "wazuh", etc.). It does NOT go through
# `consumer-template/modules/stack/`'s composition layer, so bugs that only
# manifest when consumer-template wires bundles together (wrong module
# references, ambiguous moved{} blocks, sensitive-flag propagation into
# for_each) slip past validation.
#
# This fixture closes that gap. The companion `validate.sh` script
# sed-rewrites the `?ref=v...` git URLs in consumer-template/modules/stack/*.tf
# to local relative paths before running `terraform init + validate`,
# so the working tree is what's exercised. The rewrites are reverted at end.
#
# Not intended for `apply` — providers run with dummy credentials.

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

# Exercise the FULL composition: every bundle enabled where reasonable. The
# point is to evaluate every for_each, every ternary, every cross-module
# reference downstream of var.apps / var.base / var.core / var.identity —
# that's where the v3.5.x patch series found three independent bugs.
module "stack" {
  source = "../../consumer-template/modules/stack"
  providers = {
    scaleway     = scaleway
    scaleway.dns = scaleway.dns
  }

  org_slug    = "sabokittest"
  org_name    = "Sabokit Test"
  environment = "test"

  scaleway_project_id = "00000000-0000-0000-0000-000000000000"
  scaleway_region     = "fr-par"
  scaleway_zone       = "fr-par-1"

  base_domain    = "example.org"
  mgmt_domain    = "example.org"
  gateway_domain = "auth.example.org"
  infra_email    = "ops@example.org"

  private_network_subnet = "10.0.0.0/22"

  compute_hosts = {
    tools = {
      instance_type = "DEV1-L"
      disk_size     = 100
      role          = "tools"
      ansible_group = "tools"
      protected     = true
    }
    identity = {
      instance_type = "DEV1-M"
      disk_size     = 30
      role          = "identity"
      ansible_group = "identity"
      protected     = true
    }
    management = {
      instance_type = "DEV1-M"
      disk_size     = 60
      role          = "management"
      ansible_group = "management"
      protected     = true
    }
  }

  identity = {
    tier_slots = [
      { name = "l1", peers = { member = "member" } },
      { name = "l2", peers = { delegate = "delegate" } },
      { name = "l3", peers = { admin = "admin" } },
    ]
  }

  # Exercise host-services tier (var.base.diun/autoheal/wazuh_agent for_each
  # downstream of var.base — the v3.5.3 sensitive-flag-propagation regression
  # site).
  base = {}

  # Exercise core tier (var.core.{loki,prometheus,grafana,wazuh} for_each
  # downstream of var.core — same regression class).
  core = {
    wazuh = {
      hostname = "wazuh.example.org"
    }
    grafana = {
      hostname = "grafana.example.org"
    }
  }

  # Exercise at least one app to validate the apps tier wiring.
  apps = {
    outline = {
      enabled  = true
      hostname = "wiki.example.org"
    }
  }

  bootstrap = {}

  manage_gateway_dns       = true
  gateway_compute_host_key = null
  custom_dns_records       = {}
}
