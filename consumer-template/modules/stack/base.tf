module "base" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/base/terraform?ref=v2.8.1"
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

  # App bundles export their own SG rule requirements as
  # required_inbound_rules. Aggregate here so enabling an app
  # automatically opens its ports; disabling closes them.
  default_security_group_extra_inbound_rules = concat(
    module.jitsi.required_inbound_rules,
    module.nextcloud.required_inbound_rules,
    module.wazuh.required_inbound_rules,
  )
}
