# Outputs the consumer typically wants visible after apply.

output "compute_hosts" {
  description = "Compute hosts. SSH into them with the keys you configured in Scaleway."
  value       = module.base.compute.hosts
}

output "authentik_gateway_domain" {
  description = "Where to point your DNS so users can reach Authentik."
  value       = module.base.domains.gateway_domain
}

output "postgres_admin_credentials_secret_id" {
  description = "Scaleway secret holding the Postgres admin credentials. App bundles use this for emergency access; routine app DBs are provisioned by the app bundles themselves."
  value       = module.base.scaleway.postgres_admin_credentials_secret_id
}

# Per-app outputs — the consumer can pipe these to ansible-playbook via
# `-e @<json-file>` to surface secrets and metadata to the deploy playbook.

output "enabled_apps" {
  description = "Map of enabled app name → bundle outputs. Drives Ansible's per-app deploy decisions."
  value = {
    outline = module.outline.enabled ? {
      url           = module.outline.app_url
      ansible_vars  = module.outline.ansible.vars
      ansible_group = module.outline.ansible.host_group
      monitoring    = module.outline.monitoring
    } : null
  }
}
