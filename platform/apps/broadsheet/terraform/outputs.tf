output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Broadsheet is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID (Broadsheet speaks OIDC; this is not bound to the embedded outpost)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-broadsheet)."
  value       = var.enabled ? module.authentik[0].application_group_id : null
}

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value       = local.monitoring_contribution
}

# Split-DNS contribution. Consumer-template merges every bundle's entries
# into the split_dns_overrides ansible var so each host resolves this
# hostname to the deployment host's private IP. Empty list when disabled.
output "split_dns_entries" {
  description = "Public-hostname -> private-IP overrides for cross-host resolution. Aggregated by the consumer-template."
  value = (var.enabled && var.hostname != "") ? [
    {
      hostname   = var.hostname
      private_ip = var.base.compute.hosts[var.deployment_host_key].private_ip
    },
  ] : []
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/role"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      broadsheet_hostname                 = var.hostname
      broadsheet_image                    = var.image
      broadsheet_image_tag                = var.image_tag
      broadsheet_build_from_source        = var.build_from_source
      broadsheet_image_source_repo        = var.image_source_repo
      broadsheet_image_source_ref         = var.image_source_ref
      broadsheet_app_secret_id            = scaleway_secret.app[0].id
      broadsheet_db_credentials_secret_id = module.database[0].secret_id
      broadsheet_smtp_secret_name         = var.smtp_from_email == "" ? "" : "smtp-config"
      broadsheet_auto_update_enabled      = var.auto_update_enabled
      broadsheet_autoheal_enabled         = var.autoheal_enabled
    }
  } : null
}

output "files_bucket_name" {
  description = "Name of the S3 bucket for Broadsheet files. null when disabled."
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
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Aggregated by consumer-template into backrest's backup_plans. Data lives in `/opt/broadsheet/data` (covered by opt_dir); RDB postgres and S3 templates bucket have their own managed backups."
  value = (var.enabled && var.backup_enabled) ? {
    id               = local.slug
    paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir          = true
    volumes          = []
    excluded_volumes = []
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
  } : null
}
