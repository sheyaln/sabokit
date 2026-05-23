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

output "infra_email" {
  description = "Operations contact email. Surfaced so deploy.sh can pass it through to Ansible's traefik role for the Let's Encrypt ACME registration email."
  value       = var.infra_email
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
    steward = module.steward.enabled ? {
      url           = module.steward.app_url
      ansible_vars  = module.steward.ansible.vars
      ansible_group = module.steward.ansible.host_group
    } : null
    vikunja = module.vikunja.enabled ? {
      url           = module.vikunja.app_url
      ansible_vars  = module.vikunja.ansible.vars
      ansible_group = module.vikunja.ansible.host_group
      monitoring    = module.vikunja.monitoring
    } : null
    bentopdf = module.bentopdf.enabled ? {
      url           = module.bentopdf.app_url
      ansible_vars  = module.bentopdf.ansible.vars
      ansible_group = module.bentopdf.ansible.host_group
      monitoring    = module.bentopdf.monitoring
    } : null
    notifuse = module.notifuse.enabled ? {
      url           = module.notifuse.app_url
      ansible_vars  = module.notifuse.ansible.vars
      ansible_group = module.notifuse.ansible.host_group
      monitoring    = module.notifuse.monitoring
    } : null
    privacy_policy = module.privacy_policy.enabled ? {
      url           = module.privacy_policy.app_url
      ansible_vars  = module.privacy_policy.ansible.vars
      ansible_group = module.privacy_policy.ansible.host_group
      monitoring    = module.privacy_policy.monitoring
    } : null
  }
}
