# Operations layer root. Deploys observability (loki/prometheus/grafana/wazuh)
# + the protonmail-bridge IMAP gateway. Self-discovers infra + identity by name
# via the contract — no remote_state. Apply AFTER identity (it mints OIDC apps
# against the running Authentik).
#
# Apply rhythm: TF (this) mints DBs + OIDC apps, then the operations ANSIBLE
# play deploys the containers. See scripts/operations.sh.

locals {
  env_name = basename(dirname(abspath(path.root)))
  common   = yamldecode(file("${path.root}/../../common.yml"))
  env      = yamldecode(file("${path.root}/../env.yml"))
  hosts    = yamldecode(file("${path.root}/../hosts.yml"))
  identity = yamldecode(file("${path.root}/../identity.yml"))
  infra    = yamldecode(file("${path.root}/../infra.yml"))
  ops      = yamldecode(file("${path.root}/../operations.yml"))

  # Every Authentik group name bundles might bind, for contract discovery.
  group_names = distinct(concat(
    flatten([for s in local.identity.tier_slots : values(s.peers)]),
    keys(try(local.identity.extra_groups, {})),
  ))
}

module "operations" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/operations/terraform?ref=v0.2.1-beta1"
  providers = {
    scaleway  = scaleway
    authentik = authentik
  }

  org_slug    = local.common.org_slug
  environment = local.env_name

  scaleway_project_id = local.env.scaleway_project_id
  scaleway_region     = local.env.scaleway_region
  scaleway_zone       = local.env.scaleway_zone

  private_network_subnet = local.env.private_network_subnet
  postgres_enabled       = try(local.infra.postgres_enabled, true)
  postgres_engine        = try(local.infra.postgres_engine, "PostgreSQL-16")

  base_domain      = local.env.base_domain
  mgmt_domain      = local.env.mgmt_domain != "" ? local.env.mgmt_domain : null
  identity_domain  = local.env.identity_domain
  smtp_secret_name = try(local.infra.tem_smtp_config_secret_name, "smtp-config")
  icon_base_url    = local.common.icon_base_url

  group_names   = local.group_names
  compute_hosts = local.hosts.compute_hosts

  loki              = try(local.ops.loki, {})
  prometheus        = try(local.ops.prometheus, {})
  grafana           = try(local.ops.grafana, {})
  wazuh             = try(local.ops.wazuh, {})
  protonmail_bridge = try(local.ops.protonmail_bridge, {})
}
