# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this Diun instance is enabled."
  value       = var.enabled
}

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value       = local.monitoring_contribution
}

# Diun has no public hostname, no inbound surface, no DB worth backing up
# (the local SQLite digest cache is rebuildable from a single registry sweep).
output "split_dns_entries" {
  description = "Empty — Diun has no public hostname."
  value       = []
}

output "required_inbound_rules" {
  description = "Empty — Diun is outbound-only (talks to registries and notifier endpoints)."
  value       = []
}

output "backup_plan" {
  description = "null — Diun's local digest cache is rebuildable; not worth backing up."
  value       = null
}

output "blackbox_targets" {
  description = "Empty — no public surface to probe."
  value       = []
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/diun"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      diun_instance_name           = var.instance_name
      diun_image_tag               = var.image_tag
      diun_timezone                = var.timezone
      diun_watch_schedule          = var.watch_schedule
      diun_watch_workers           = var.watch_workers
      diun_watch_first_check_notif = var.watch_first_check_notif
      diun_watch_by_default        = var.watch_by_default
      diun_default_watch_repo      = var.default_watch_repo
      diun_include_swarm_services  = var.include_swarm_services
      diun_notification_targets    = var.notification_targets
      diun_auto_update_enabled     = var.auto_update_enabled
      diun_autoheal_enabled        = var.autoheal_enabled
    }
  } : null
}

output "instance_name" {
  description = "The instance_name passed in, echoed back so consumers can index module outputs alongside their config."
  value       = var.instance_name
}
