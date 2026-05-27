# Per-env root. Wires per-env vars (from terraform.tfvars) + persistent config
# (from config.tf) into the shared stack module. Upstream-maintained —
# consumers should not need to edit this file during normal operation. Add
# sibling .tf files in this directory for consumer-owned resources.
#
# `terraform.tfvars` → per-env values (project_id, domains, instance sizes; gitignored)
# `config.tf`        → persistent infra shape (apps catalog, host topology, tier_slots; committable)
# `secrets.tf`       → Scaleway secret data sources (bag IDs committable; payloads not)
# `backend.hcl`      → remote state config (gitignored)
# `inventory.ini`    → Ansible inventory (gitignored; built from `terraform output compute_hosts`)

module "stack" {
  source = "../../modules/stack"
  providers = {
    scaleway     = scaleway
    scaleway.dns = scaleway.dns
  }

  # Persistent (config.tf)
  org_slug = local.config.org_slug
  org_name = local.config.org_name

  # Per-env (terraform.tfvars)
  environment = var.environment

  scaleway_project_id = var.scaleway_project_id
  scaleway_region     = var.scaleway_region
  scaleway_zone       = var.scaleway_zone

  base_domain    = var.base_domain
  mgmt_domain    = var.mgmt_domain != "" ? var.mgmt_domain : null
  gateway_domain = var.gateway_domain
  infra_email    = var.infra_email

  compute_hosts          = local.config.compute_hosts
  private_network_subnet = var.private_network_subnet

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

output "authentik_gateway_domain" {
  value = module.stack.authentik_gateway_domain
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
