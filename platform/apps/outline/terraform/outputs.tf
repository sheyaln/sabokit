# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Outline is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID. null for non-forward-auth apps (Outline is OIDC, so this is the OIDC provider ID — not bound to the embedded outpost)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-outline). Used by service accounts that need direct access."
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
      outline_hostname                 = var.hostname
      outline_image_tag                = var.image_tag
      outline_app_secret_id            = scaleway_secret.app[0].id
      outline_db_credentials_secret_id = module.database[0].secret_id
      # SMTP is opt-in: empty smtp_from_email means SMTP is off and Outline
      # should skip the lookup entirely. The Ansible role guards on this.
      outline_smtp_secret_name = var.smtp_from_email == "" ? "" : "smtp-config"
    }
  } : null
}

# Convenience outputs for cross-app integrations or admin tooling.

output "attachments_bucket_name" {
  description = "Name of the S3 bucket for attachments. null when disabled."
  value       = var.enabled ? module.attachments_bucket[0].name : null
}

output "database_name" {
  description = "PostgreSQL database name. null when disabled."
  value       = var.enabled ? module.database[0].database_name : null
}
