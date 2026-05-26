# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Steward is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-steward). Used by service accounts that need direct access."
  value       = var.enabled ? module.authentik[0].application_group_id : null
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
    role_path  = "${path.module}/../ansible/roles"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      steward_hostname                 = var.hostname
      steward_image_repository         = var.image_repository
      steward_image_tag                = var.image_tag
      steward_app_secret_id            = local.app_secret_id
      steward_db_credentials_secret_id = module.database[0].secret_id
      steward_memory_limit             = var.memory_limit
      steward_memory_reservation       = var.memory_reservation
      steward_cpu_limit                = var.cpu_limit
      steward_cpu_reservation          = var.cpu_reservation
      steward_auto_update_enabled      = var.auto_update_enabled
      steward_autoheal_enabled         = var.autoheal_enabled
    }
  } : null
}

output "monitoring" {
  description = "Monitoring contribution. null when disabled or monitoring_enabled = false."
  value       = local.monitoring_contribution
}

output "database_name" {
  description = "PostgreSQL database name. null when disabled."
  value       = var.enabled ? module.database[0].database_name : null
}

output "service_steward_token_secret_hint" {
  description = "Hint pointing to where the Authentik API token lives (inside the app_secret_id bag under AUTHENTIK_API_TOKEN). The token itself is not exported. Renamed from service_account_token_secret_hint in v2.15.1 to match the platform service-account naming convention (`service_<thing>` / `svc-<thing>`)."
  value       = var.enabled ? "Inside ${local.app_secret_name}, key AUTHENTIK_API_TOKEN" : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Aggregated by consumer-template into backrest's backup_plans. RDB postgres has its own managed backups; `steward-media` carries user-uploaded files; `steward-static` is collected at image build and regenerable."
  value = (var.enabled && var.backup_enabled) ? {
    id               = local.slug
    paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir          = true
    volumes          = ["steward-media"]
    excluded_volumes = ["steward-static"]
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
  } : null
}
