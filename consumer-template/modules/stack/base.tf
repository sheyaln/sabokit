module "base" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/base/terraform?ref=v1.0.0"

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
}
