# Infra layer root. Provisions the Scaleway substrate: VPC, compute hosts,
# per-role security groups, managed Postgres (incl. Authentik's DB — the
# root-of-trust fold), TEM outbound mail, gateway DNS, and per-host watchers.
# Apply this FIRST; the other layers discover its resources by name.
#
# Config (all committed, no secrets):
#   ../../common.yml  org identity        ../hosts.yml  compute topology
#   ../env.yml        per-env scope/sizing ../infra.yml  this layer's knobs

locals {
  env_name = basename(dirname(abspath(path.root)))
  common   = yamldecode(file("${path.root}/../../common.yml"))
  env      = yamldecode(file("${path.root}/../env.yml"))
  hosts    = yamldecode(file("${path.root}/../hosts.yml"))
  infra    = yamldecode(file("${path.root}/../infra.yml"))

  # Merge per-env sizing (env.yml, keyed by host KEY) into the persistent
  # topology (hosts.yml). Keyed by the host key, not role — a host's role
  # (apps/auth/…) need not equal its key (tools/identity/…), and sizing is
  # per-host. The module needs instance_type + disk_size per host.
  compute_hosts = {
    for k, h in local.hosts.compute_hosts : k => merge(h, {
      instance_type = local.env.compute_instance_types[k]
      disk_size     = local.env.compute_disk_sizes[k]
    })
  }
}

module "infra" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/infra/terraform?ref=v0.2.1-beta1"
  providers = {
    scaleway     = scaleway
    scaleway.dns = scaleway.dns
  }

  org_slug    = local.common.org_slug
  environment = local.env_name

  scaleway_project_id = local.env.scaleway_project_id
  scaleway_region     = local.env.scaleway_region
  scaleway_zone       = local.env.scaleway_zone

  base_domain     = local.env.base_domain
  mgmt_domain     = local.env.mgmt_domain != "" ? local.env.mgmt_domain : null
  identity_domain = local.env.identity_domain
  infra_email     = local.env.infra_email

  private_network_subnet = local.env.private_network_subnet
  compute_hosts          = local.compute_hosts

  manage_gateway_dns          = try(local.infra.manage_gateway_dns, true)
  gateway_compute_host_key    = try(local.infra.gateway_compute_host_key, null)
  custom_dns_records          = try(local.infra.custom_dns_records, {})
  extra_inbound_rules_by_role = try(local.infra.extra_inbound_rules_by_role, {})

  postgres_enabled           = try(local.infra.postgres_enabled, true)
  postgres_engine            = try(local.infra.postgres_engine, "PostgreSQL-16")
  postgres_node_type         = try(local.infra.postgres_node_type, "db-dev-s")
  postgres_high_availability = try(local.infra.postgres_high_availability, false)

  authentik_version = try(local.infra.authentik_version, "")

  tem_enabled               = try(local.infra.tem_enabled, true)
  tem_webhook_name_override = try(local.infra.tem_webhook_name_override, "")
  tem_webhook_n8n_url       = try(local.infra.tem_webhook_n8n_url, "")
  dmarc_rua_email           = try(local.infra.dmarc_rua_email, "")

  autoheal    = try(local.infra.autoheal, {})
  diun        = try(local.infra.diun, {})
  wazuh_agent = try(local.infra.wazuh_agent, {})
}
