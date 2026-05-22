# What the per-env root surfaces to the consumer (and to Ansible via
# deploy.sh's `terraform output -json enabled_apps`).

output "compute_hosts" {
  description = "Compute hosts. SSH in with the keys configured in Scaleway."
  value       = module.base.compute.hosts
}

output "authentik_gateway_domain" {
  description = "Where to point DNS so users can reach Authentik."
  value       = module.base.domains.gateway_domain
}

output "postgres_admin_credentials_secret_id" {
  description = "Scaleway secret holding Postgres admin credentials. App bundles use this for emergency access; routine per-app DBs are owned by the app bundles."
  value       = module.base.scaleway.postgres_admin_credentials_secret_id
}

output "identity_bootstrap" {
  description = "Map of Scaleway secret IDs the Ansible bootstrap.yml feeds to the authentik-server role. Passed verbatim as -e identity_bootstrap=$(terraform output -json identity_bootstrap)."
  value       = module.identity_bootstrap.identity_bootstrap
}

output "authentik_admin_secret_id" {
  description = "Scaleway secret holding the Authentik bootstrap admin credentials JSON {username, email, password, api_token}. deploy.sh fetches api_token from here for TF_VAR_authentik_admin_token."
  value       = module.identity_bootstrap.admin_secret_id
}

output "enabled_apps" {
  description = "Map of enabled app name -> bundle outputs. Consumed by Ansible via `terraform output -json enabled_apps`."
  value = {
    outline = module.outline.enabled ? {
      url           = module.outline.app_url
      ansible_vars  = module.outline.ansible.vars
      ansible_group = module.outline.ansible.host_group
      monitoring    = module.outline.monitoring
    } : null
  }
}
