# Per-env root. Calls the shared stack module with this env's variables.
#
# `terraform.tfvars`  → env-specific values (gitignored)
# `backend.hcl`       → remote state config (gitignored if it contains the bucket name)
# `inventory.ini`     → Ansible inventory (gitignored; built from `terraform output compute_hosts`)
# `deploy.sh`         → `terraform apply && ansible-playbook …`

module "stack" {
  source = "../../modules/stack"
  providers = {
    scaleway     = scaleway
    scaleway.dns = scaleway.dns
  }

  org_slug    = var.org_slug
  org_name    = var.org_name
  environment = var.environment

  scaleway_project_id = var.scaleway_project_id
  scaleway_region     = var.scaleway_region
  scaleway_zone       = var.scaleway_zone

  base_domain    = var.base_domain
  mgmt_domain    = var.mgmt_domain
  gateway_domain = var.gateway_domain
  infra_email    = var.infra_email

  compute_hosts          = var.compute_hosts
  private_network_subnet = var.private_network_subnet

  apps             = var.apps
  smtp_secret_name = var.smtp_secret_name

  manage_gateway_dns       = var.manage_gateway_dns
  gateway_compute_host_key = var.gateway_compute_host_key
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
  value = module.stack.enabled_apps
}
