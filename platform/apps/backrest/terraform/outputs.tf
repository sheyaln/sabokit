# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this Backrest instance is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where this Backrest instance is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "Authentik proxy-provider ID. The consumer MUST include this in identity's `extra_forward_auth_provider_ids` for the embedded outpost to protect this instance — Backrest's built-in auth is disabled and the outpost is the only gate."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-instance Authentik group (app-backrest-<instance_name>). Used by service accounts that need direct access."
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
    role_path  = "${path.module}/../ansible/roles/backrest"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      backrest_instance_name                     = var.instance_name
      backrest_hostname                          = var.hostname
      backrest_image_tag                         = var.image_tag
      backrest_app_secret_id                     = local.app_secret_id
      backrest_backup_plans                      = var.backup_plans
      backrest_backup_sources                    = var.backup_sources
      backrest_restic_prune_max_frequency_days   = var.restic_prune_max_frequency_days
      backrest_restic_check_max_frequency_days   = var.restic_check_max_frequency_days
      backrest_restic_check_read_data_subset_pct = var.restic_check_read_data_subset_percent
      backrest_restic_s3_storage_class           = var.storage_class
      backrest_diun_watch_enabled                = var.diun_watch_enabled
      backrest_autoheal_enabled                  = var.autoheal_enabled
      backrest_extra_env_vars                    = var.extra_env_vars
    }
  } : null
}

# Convenience outputs for cross-app integrations or ops tooling.

output "instance_name" {
  description = "The instance_name passed in, echoed back so consumers can index module outputs alongside their config."
  value       = var.instance_name
}

output "bucket_name" {
  description = "Name of the S3 bucket holding this instance's restic repo. null when disabled."
  value       = var.enabled ? module.bucket[0].name : null
}
