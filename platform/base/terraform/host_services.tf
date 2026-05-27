# Per-host auto-instantiation of host-services bundles. One module call per
# entry in var.compute_hosts, gated by each service's `enabled` flag and
# `disabled_hosts` opt-out list. Services default-on (see ARCHITECTURE.md
# host-services sub-tier section).
#
# Each bundle's `base` input gets a self-shaped object built from the same
# locals that feed the public base outputs — avoids a circular module
# dependency while keeping the bundle contract identical to the app-tier.

locals {
  host_services_base_self = {
    scaleway = local.scaleway_output
    compute  = local.compute_output
    domains  = local.domains_output
  }

  autoheal_hosts = {
    for k, h in var.compute_hosts : k => h
    if var.autoheal.enabled && !contains(var.autoheal.disabled_hosts, k)
  }
}

module "autoheal" {
  source = "../host-services/autoheal/terraform"

  for_each = local.autoheal_hosts

  enabled = true
  base    = local.host_services_base_self

  deployment_host_key  = each.key
  image_tag            = var.autoheal.image_tag
  interval_seconds     = var.autoheal.interval_seconds
  start_period_seconds = var.autoheal.start_period_seconds
}
