# Per-env root. Wires per-env values (from env-values.yml via env.tf) + the
# persistent shape (from config.tf) into the shared stack module. Upstream-
# maintained — consumers should not need to edit this file during normal
# operation. Add sibling .tf files in this directory for consumer-owned resources.
#
# `../env-values.yml` → per-env NON-secret values, keyed by env name (committed)
# `env.tf`            → resolves this dir's slice -> local.env / local.env_name
# `config.tf`         → persistent infra shape (apps catalog, host topology, tier_slots; committed)
# `secrets.tf`        → Scaleway secret data sources (bag IDs committable; payloads not)
# `backend.hcl`       → remote state config (gitignored)
# `inventory.ini`     → Ansible inventory (gitignored; built from `terraform output compute_hosts`)

module "stack" {
  source = "../../modules/stack"
  providers = {
    scaleway     = scaleway
    scaleway.dns = scaleway.dns
  }

  # Persistent (config.tf)
  org_slug = local.config.org_slug
  org_name = local.config.org_name

  # Per-env (env-values.yml, selected by directory name -> local.env / local.env_name)
  environment = local.env_name

  scaleway_project_id = local.env.scaleway_project_id
  scaleway_region     = local.env.scaleway_region
  scaleway_zone       = local.env.scaleway_zone

  base_domain     = local.env.base_domain
  mgmt_domain     = local.env.mgmt_domain != "" ? local.env.mgmt_domain : null
  identity_domain = local.env.identity_domain
  infra_email     = local.env.infra_email

  compute_hosts          = local.config.compute_hosts
  private_network_subnet = local.env.private_network_subnet

  # Persistent (config.tf)
  identity         = local.config.identity
  apps             = try(local.config.apps, {})
  bootstrap        = try(local.config.bootstrap, {})
  base             = try(local.config.base, {})
  smtp_secret_name = try(local.config.smtp_secret_name, "")

  manage_gateway_dns       = try(local.config.manage_gateway_dns, true)
  gateway_compute_host_key = try(local.config.gateway_compute_host_key, null)

  custom_dns_records = try(local.config.custom_dns_records, {})
}

# Surface stack outputs so `terraform output` / `terraform output -json` works
# without poking into module internals.

output "compute_hosts" {
  value = module.stack.compute_hosts
}

output "authentik_identity_domain" {
  value = module.stack.authentik_identity_domain
}

output "postgres_admin_credentials_secret_id" {
  value = module.stack.postgres_admin_credentials_secret_id
}

output "identity_bootstrap" {
  value = module.stack.identity_bootstrap
}

output "authentik_admin_secret_id" {
  value = module.stack.authentik_admin_secret_id
}

output "infra_email" {
  value = module.stack.infra_email
}

output "enabled_apps" {
  value     = module.stack.enabled_apps
  sensitive = true
}

output "split_dns_overrides" {
  value = module.stack.split_dns_overrides
}

output "monitoring_loki_push_url" {
  value = module.stack.monitoring_loki_push_url
}

output "spf_include" {
  value = module.stack.spf_include
}
