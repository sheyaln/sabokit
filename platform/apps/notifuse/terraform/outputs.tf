output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Notifuse is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID (Notifuse speaks OIDC; this is not bound to the embedded outpost)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-notifuse)."
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
      notifuse_hostname                 = var.hostname
      notifuse_image                    = var.image
      notifuse_image_tag                = var.image_tag
      notifuse_build_from_source        = var.build_from_source
      notifuse_image_source_repo        = var.image_source_repo
      notifuse_image_source_ref         = var.image_source_ref
      notifuse_app_secret_id            = scaleway_secret.app[0].id
      notifuse_db_credentials_secret_id = module.database[0].secret_id
      notifuse_smtp_secret_name         = var.smtp_from_email == "" ? "" : "smtp-config"
      notifuse_auto_update_enabled      = var.auto_update_enabled
      notifuse_autoheal_enabled         = var.autoheal_enabled
    }
  } : null
}

output "files_bucket_name" {
  description = "Name of the S3 bucket for Notifuse files. null when disabled."
  value       = var.enabled ? module.files_bucket[0].name : null
}

output "database_name" {
  description = "PostgreSQL database name. null when disabled."
  value       = var.enabled ? module.database[0].database_name : null
}

output "root_admin_email" {
  description = "Email address of the initial root admin (echoed back for documentation; the password is in the app-secrets bag)."
  value       = var.enabled ? var.root_admin_email : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Aggregated by consumer-template into backrest's backup_plans."
  value = (var.enabled && var.backup_enabled) ? {
    id        = local.slug
    paths     = concat(["/backup-sources/opt/${local.slug}"], var.backup_extra_paths)
    excludes  = []
    schedule  = { cron = var.backup_schedule_cron }
    retention = var.backup_retention
  } : null
}
