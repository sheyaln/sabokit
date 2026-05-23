# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Vikunja is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID. null for non-forward-auth apps (Vikunja is OIDC, so this is the OIDC provider ID — not bound to the embedded outpost)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-vikunja). Used by service accounts that need direct access."
  value       = var.enabled ? module.authentik[0].application_group_id : null
}

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value       = local.monitoring_contribution
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/role"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      vikunja_hostname                 = var.hostname
      vikunja_image_tag                = var.image_tag
      vikunja_timezone                 = var.timezone
      vikunja_enable_registration      = var.enable_registration
      vikunja_enable_local_auth        = var.enable_local_auth
      vikunja_app_secret_id            = scaleway_secret.app[0].id
      vikunja_db_credentials_secret_id = module.database[0].secret_id
      vikunja_smtp_secret_name         = var.smtp_from_email == "" ? "" : "smtp-config"
    }
  } : null
}

output "database_name" {
  description = "PostgreSQL database name. null when disabled."
  value       = var.enabled ? module.database[0].database_name : null
}
