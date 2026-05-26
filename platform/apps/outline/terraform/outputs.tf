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
      outline_hostname                 = var.hostname
      outline_image_tag                = var.image_tag
      outline_app_secret_id            = local.app_secret_id
      outline_db_credentials_secret_id = module.database[0].secret_id
      # SMTP is opt-in: empty smtp_from_email means SMTP is off and Outline
      # should skip the lookup entirely. The Ansible role guards on this.
      outline_smtp_secret_name   = var.smtp_from_email == "" ? "" : "smtp-config"
      outline_diun_watch_enabled = var.diun_watch_enabled
      outline_autoheal_enabled   = var.autoheal_enabled
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Consumer-template aggregates contributions across all apps and passes the list to the backrest module call (same shape as `required_inbound_rules` for SG rules — bundles own their backup story, consumer just plumbs). Attachments + storage live in Scaleway S3 (backed at the cloud layer); redis is a cache."
  value = (var.enabled && var.backup_enabled) ? {
    id               = local.slug
    paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir          = true
    volumes          = []
    excluded_volumes = ["redis-data", "storage-data"]
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
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
