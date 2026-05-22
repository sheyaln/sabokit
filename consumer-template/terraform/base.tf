module "base" {
  source = "git::https://github.com/sheyaln/sabokit.git//base/scaleway?ref=v1.0.0"

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

module "authentik" {
  source = "git::https://github.com/sheyaln/sabokit.git//base/authentik?ref=v1.0.0"

  gateway_domain = module.base.domains.gateway_domain
  base_domain    = module.base.domains.base_domain

  org_name    = title(var.org_slug)
  org_slug    = var.org_slug
  infra_email = "ops@${var.base_domain}"

  # Forward-auth providers from any enabled apps/* bundles plug in here.
  # compact() drops nulls from disabled apps.
  extra_forward_auth_provider_ids = compact([
    # Example (uncomment when bundles ship):
    # module.bentopdf.authentik_provider_id,
    # module.backrest.authentik_provider_id,
  ])
}

# Convenience local: the merged "base" object that app bundles consume.
# Apps reference var.base.{scaleway,authentik,compute,domains}.
locals {
  base = {
    scaleway  = module.base.scaleway
    compute   = module.base.compute
    domains   = module.base.domains
    authentik = module.authentik.authentik
  }
}
