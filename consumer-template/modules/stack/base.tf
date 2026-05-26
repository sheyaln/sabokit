module "base" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/base/terraform?ref=v3.1.12"
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

  postgres_credentials_preserve = try(var.base.postgres_credentials_preserve, false)

  # Auto-wire TEM delivery webhook → SNS → n8n when n8n is enabled and exports
  # a URL. The base module emits zero webhook resources when the URL is empty.
  tem_webhook_n8n_url = module.n8n.enabled ? coalesce(module.n8n.app_url, "") : ""

  # App bundles export their own SG rule requirements as
  # required_inbound_rules. Aggregate here so enabling an app
  # automatically opens its ports; disabling closes them.
  default_security_group_extra_inbound_rules = concat(
    module.jitsi.required_inbound_rules,
    module.nextcloud.required_inbound_rules,
    module.wazuh.required_inbound_rules,
  )
}
