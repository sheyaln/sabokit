module "base" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/base/terraform?ref=v0.1.0"
  providers = {
    scaleway     = scaleway
    scaleway.dns = scaleway.dns
  }

  org_slug    = var.org_slug
  environment = var.environment

  scaleway_project_id = var.scaleway_project_id
  scaleway_region     = var.scaleway_region
  scaleway_zone       = var.scaleway_zone

  base_domain    = var.base_domain
  mgmt_domain    = var.mgmt_domain
  gateway_domain = var.gateway_domain

  private_network_subnet = var.private_network_subnet
  compute_hosts          = var.compute_hosts

  manage_gateway_dns       = var.manage_gateway_dns
  gateway_compute_host_key = var.gateway_compute_host_key

  custom_dns_records = var.custom_dns_records


  # Host-services (per-host runtime watchers). Default-on category — pass
  # the consumer's nested override map straight through, base layer applies
  # the per-service defaults.
  autoheal = try(var.base.autoheal, {})

  # Auto-wire TEM delivery webhook → SNS → n8n when n8n is enabled and exports
  # a URL. The base module emits zero webhook resources when the URL is empty.
  tem_webhook_n8n_url       = module.n8n.enabled ? coalesce(module.n8n.app_url, "") : ""
  tem_webhook_name_override = try(var.base.tem_webhook_name_override, "")

  # Host-services sub-tier (one container per compute_host). Default-on as a
  # category; consumers flip `enabled = false` to turn a service off entirely
  # or list compute_host keys in `disabled_hosts` for per-host opt-out.
  # `n8n_webhook_url` auto-wires to the n8n bundle when enabled — consumer
  # override via `var.base.diun.n8n_webhook_url` wins.
  diun = merge(
    try(var.base.diun, {}),
    {
      n8n_webhook_url = try(
        var.base.diun.n8n_webhook_url,
        module.n8n.enabled ? "${coalesce(module.n8n.app_url, "")}/webhook/diun-image-update" : "",
      )
    },
  )

  # App bundles export their own SG rule requirements as
  # required_inbound_rules. Aggregate here so enabling an app
  # automatically opens its ports; disabling closes them.
  default_security_group_extra_inbound_rules = concat(
    module.jitsi.required_inbound_rules,
    module.nextcloud.required_inbound_rules,
    module.core.required_inbound_rules,
  )

  # Host-services tier. Default-on; consumers opt out via
  # `var.base.<service>.enabled = false` or per-host via
  # `var.base.<service>.disabled_hosts = [...]`.
  # wazuh-agent's manager_address falls through to module.core.wazuh.manager_private_ip
  # when the manager app is enabled and the consumer didn't override. wazuh
  # manager moved to platform/core/ at v3.4.0 — this fallback follows.
  wazuh_agent = merge(
    try(var.base.wazuh_agent, {}),
    {
      manager_address = try(var.base.wazuh_agent.manager_address, "") != "" ? var.base.wazuh_agent.manager_address : (try(module.core.wazuh.enabled, false) ? module.core.wazuh.manager_private_ip : "")
    },
  )
}
