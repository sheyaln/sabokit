# Per-host auto-instantiation of host-services bundles. One module call per
# entry in var.compute_hosts, gated by var.<service>.enabled +
# disabled_hosts. Each service is default-on as a category; turn off via
# `var.<service>.enabled = false` (whole service) or per-host opt-out via
# `var.<service>.disabled_hosts`.
#
# Host-services bundles are self-contained — they only need a minimal slice
# of the base contract (compute.hosts[host_key].ansible_group). We pass that
# subset rather than reaching across the layered model.

locals {
  # Subset of the apps-facing base object the host-services bundles consume.
  # Bundles read `var.base.compute.hosts[var.deployment_host_key].ansible_group`
  # — that's the entire surface; nothing else is needed inside this tier.
  host_services_base = {
    compute = local.compute_output
  }
}

module "diun" {
  source   = "../host-services/diun/terraform"
  for_each = var.diun.enabled ? { for k, v in var.compute_hosts : k => v if !contains(var.diun.disabled_hosts, k) } : {}

  enabled       = true
  base          = local.host_services_base
  instance_name = each.key

  deployment_host_key = each.key

  image_tag               = var.diun.image_tag
  timezone                = var.diun.timezone
  watch_schedule          = var.diun.watch_schedule
  watch_workers           = var.diun.watch_workers
  watch_first_check_notif = var.diun.watch_first_check_notif
  watch_by_default        = var.diun.watch_by_default
  default_watch_repo      = var.diun.default_watch_repo
  include_swarm_services  = var.diun.include_swarm_services
  notification_targets    = var.diun.notification_targets
  diun_notif_extra        = var.diun.diun_notif_extra
  diun_watch_enabled      = var.diun.diun_watch_enabled
  autoheal_enabled        = var.diun.autoheal_enabled
  monitoring_enabled      = var.diun.monitoring_enabled
  n8n_webhook_url         = var.diun.n8n_webhook_url
  extra_env_vars          = var.diun.extra_env_vars
}
