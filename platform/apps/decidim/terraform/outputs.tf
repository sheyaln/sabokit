# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Decidim is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID. null for non-forward-auth apps (Decidim speaks OIDC; this is the OIDC provider ID — not bound to the embedded outpost)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-decidim). Used by service accounts that need direct access."
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
    role_path  = "${path.module}/../ansible/roles/decidim"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      decidim_hostname                 = var.hostname
      decidim_image                    = var.image
      decidim_image_tag                = var.image_tag
      decidim_extra_gems               = var.extra_gems
      decidim_app_secret_id            = local.app_secret_id
      decidim_db_credentials_secret_id = module.database[0].secret_id
      decidim_sidekiq_concurrency      = var.sidekiq_concurrency
      decidim_max_upload_size_bytes    = var.max_upload_size_bytes
      # SMTP is opt-in: empty smtp_from_email means SMTP is off and the role
      # should skip the lookup entirely.
      decidim_smtp_secret_name      = var.smtp_from_email == "" ? "" : "smtp-config"
      decidim_diun_watch_enabled    = var.diun_watch_enabled
      decidim_autoheal_enabled      = var.autoheal_enabled
      decidim_extra_env_vars        = var.extra_env_vars
      decidim_extra_docker_networks = var.extra_docker_networks
      decidim_org_admin_name        = var.organization_admin_name
      decidim_org_admin_nickname    = var.organization_admin_nickname
    }
  } : null
}

# Convenience outputs for cross-app integrations or admin tooling.

output "uploads_bucket_name" {
  description = "Name of the S3 bucket for uploads. null when disabled."
  value       = var.enabled ? module.uploads_bucket[0].name : null
}

output "database_name" {
  description = "PostgreSQL database name. null when disabled."
  value       = var.enabled ? module.database[0].database_name : null
}

output "system_admin_email" {
  description = "Email of the initial /system superuser (echoed back for documentation; password is in the app-secrets bag)."
  value       = var.enabled ? var.system_admin_email : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Aggregated by consumer-template into backrest's backup_plans. `uploads-data` is user content; RDB postgres handles its own backups. Logs/redis-cache/init-marker are excluded."
  value = (var.enabled && var.backup_enabled) ? {
    id               = local.slug
    paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir          = true
    volumes          = ["uploads-data"]
    excluded_volumes = ["logs-data", "redis-data", "init-marker"]
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
  } : null
}
