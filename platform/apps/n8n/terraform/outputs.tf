# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where n8n is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID. null for non-forward-auth apps (n8n is OIDC, so this is the OIDC provider ID — not bound to the embedded outpost)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-n8n). Used by service accounts that need direct access to n8n."
  value       = var.enabled ? module.authentik[0].application_group_id : null
}

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value       = local.monitoring_contribution
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/n8n"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      n8n_hostname                 = var.hostname
      n8n_image_tag                = var.image_tag
      n8n_timezone                 = var.timezone
      n8n_public_api_disabled      = var.public_api_disabled
      n8n_python_stdlib_allow      = var.python_stdlib_allow
      n8n_python_external_allow    = var.python_external_allow
      n8n_webhook_rate_limit_avg   = var.webhook_rate_limit_average
      n8n_webhook_rate_limit_burst = var.webhook_rate_limit_burst
      n8n_webhook_rate_limit_per   = var.webhook_rate_limit_period
      n8n_app_secret_id            = scaleway_secret.app[0].id
      n8n_db_credentials_secret_id = module.database[0].secret_id
    }
  } : null
}

output "database_name" {
  description = "PostgreSQL database name. null when disabled."
  value       = var.enabled ? module.database[0].database_name : null
}
