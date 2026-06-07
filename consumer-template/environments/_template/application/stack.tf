# Application layer root. Deploys the user-facing app suite + the embedded
# forward-auth outpost. Self-discovers infra + identity by name via the contract
# — no remote_state. Apply AFTER identity. Churns most often (apps come and go).
#
# Apply rhythm: TF (this) mints per-app DBs + OIDC apps + the outpost, then the
# application ANSIBLE play deploys the containers. See scripts/application.sh.

locals {
  env_name = basename(dirname(abspath(path.root)))
  common   = yamldecode(file("${path.root}/../../common.yml"))
  env      = yamldecode(file("${path.root}/../env.yml"))
  hosts    = yamldecode(file("${path.root}/../hosts.yml"))
  identity = yamldecode(file("${path.root}/../identity.yml"))
  infra    = yamldecode(file("${path.root}/../infra.yml"))
  app      = yamldecode(file("${path.root}/../application.yml"))

  group_names = distinct(concat(
    flatten([for s in local.identity.tier_slots : values(s.peers)]),
    keys(try(local.identity.extra_groups, {})),
  ))
}

module "application" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/application/terraform?ref=v0.1.0"
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

  outline        = try(local.app.outline, {})
  steward        = try(local.app.steward, {})
  vikunja        = try(local.app.vikunja, {})
  bentopdf       = try(local.app.bentopdf, {})
  privacy_policy = try(local.app.privacy_policy, {})
  broadsheet     = try(local.app.broadsheet, {})
  nextcloud      = try(local.app.nextcloud, {})
  decidim        = try(local.app.decidim, {})
  jitsi          = try(local.app.jitsi, {})
  espocrm        = try(local.app.espocrm, {})
  n8n            = try(local.app.n8n, {})
  backrest       = try(local.app.backrest, {})
}
