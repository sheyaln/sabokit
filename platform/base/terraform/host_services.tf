# Per-host auto-instantiation of host-services bundles. One module call per
# entry in var.compute_hosts, gated by each service's `enabled` flag and
# `disabled_hosts` opt-out list. Services default-on (see ARCHITECTURE.md
# host-services sub-tier section).
#
# Host-services bundles are self-contained — they only need a minimal slice
# of the base contract (compute.hosts[host_key].ansible_group). We pass that
# subset rather than reaching across the layered model — avoids a circular
# module dependency while keeping the bundle contract identical to the app-tier.

locals {
  host_services_base = {
    scaleway = local.scaleway_output
    compute  = local.compute_output
    domains  = local.domains_output
  }

  autoheal_hosts = {
    for k, h in var.compute_hosts : k => h
    if var.autoheal.enabled && !contains(var.autoheal.disabled_hosts, k)
  }

  wazuh_agent_hosts = var.wazuh_agent.enabled ? {
    for k, _ in var.compute_hosts : k => k
    if !contains(var.wazuh_agent.disabled_hosts, k)
  } : {}
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

module "autoheal" {
  source   = "../host-services/autoheal/terraform"
  for_each = local.autoheal_hosts

  enabled = true
  base    = local.host_services_base

  deployment_host_key  = each.key
  image_tag            = var.autoheal.image_tag
  interval_seconds     = var.autoheal.interval_seconds
  start_period_seconds = var.autoheal.start_period_seconds
}

module "wazuh_agent" {
  source   = "../host-services/wazuh-agent/terraform"
  for_each = local.wazuh_agent_hosts

  enabled             = true
  base                = local.host_services_base
  deployment_host_key = each.value

  image                = var.wazuh_agent.image
  release_version      = var.wazuh_agent.release_version
  manager_address      = var.wazuh_agent.manager_address
  fim_enabled          = var.wazuh_agent.fim_enabled
  fim_extra_paths      = var.wazuh_agent.fim_extra_paths
  fim_extra_exclusions = var.wazuh_agent.fim_extra_exclusions
  diun_watch_enabled   = var.wazuh_agent.diun_watch_enabled
  autoheal_enabled     = var.wazuh_agent.autoheal_enabled
  extra_env_vars       = var.wazuh_agent.extra_env_vars
}
