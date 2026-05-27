# Per-host auto-instantiation of host-services bundles. One module call per
# entry in var.compute_hosts, gated by var.<service>.enabled +
# disabled_hosts. Each service is default-on; consumers opt out per-host
# via disabled_hosts or whole-service via enabled = false.

# The shape host-services bundles expect for var.base. Mirrors the public
# outputs so a future move of any bundle from platform/apps/ to here is just
# a wiring change, not a contract change.
locals {
  self_base = {
    scaleway = local.scaleway_output
    compute  = local.compute_output
    domains  = local.domains_output
  }

  wazuh_agent_hosts = var.wazuh_agent.enabled ? {
    for k, _ in var.compute_hosts : k => k
    if !contains(var.wazuh_agent.disabled_hosts, k)
  } : {}
}

module "wazuh_agent" {
  source   = "../host-services/wazuh-agent/terraform"
  for_each = local.wazuh_agent_hosts

  enabled             = true
  base                = local.self_base
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
