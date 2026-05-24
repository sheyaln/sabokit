# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/prometheus"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      prometheus_image                          = var.image
      prometheus_image_tag                      = var.image_tag
      prometheus_retention                      = var.retention
      prometheus_scrape_configs                 = var.scrape_configs
      prometheus_alert_rules                    = var.alert_rules
      prometheus_exporters_enabled              = var.exporters_enabled
      prometheus_remote_write_enabled           = var.remote_write_enabled
      prometheus_private_ip_bind                = var.private_ip_bind
      prometheus_memory_limit                   = var.memory_limit
      prometheus_memory_reservation             = var.memory_reservation
      prometheus_cpu_limit                      = var.cpu_limit
      prometheus_cpu_reservation                = var.cpu_reservation
      prometheus_timezone                       = var.timezone
      prometheus_auto_update_enabled            = var.auto_update_enabled
      prometheus_autoheal_enabled               = var.autoheal_enabled
      prometheus_tem_exporter_enabled           = var.tem_exporter_enabled
      prometheus_tem_smtp_secret_id             = var.tem_smtp_secret_id
      prometheus_tem_scaleway_project_id        = var.tem_scaleway_project_id
      prometheus_tem_scaleway_region            = var.tem_scaleway_region
      prometheus_tem_exporter_poll_interval     = var.tem_exporter_poll_interval_seconds
      prometheus_tem_exporter_lookback_minutes  = var.tem_exporter_lookback_minutes
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false."
  value = (var.enabled && var.backup_enabled) ? {
    id        = local.slug
    paths     = concat(["/backup-sources/opt/${local.slug}"], var.backup_extra_paths)
    excludes  = []
    schedule  = { cron = var.backup_schedule_cron }
    retention = var.backup_retention
  } : null
}
