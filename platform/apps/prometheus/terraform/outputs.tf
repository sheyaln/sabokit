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
      prometheus_image                         = var.image
      prometheus_image_tag                     = var.image_tag
      prometheus_retention                     = var.retention
      prometheus_scrape_configs                = var.scrape_configs
      prometheus_extra_scrape_targets          = var.extra_scrape_targets
      prometheus_alert_rules                   = var.alert_rules
      prometheus_exporters_enabled             = var.exporters_enabled
      prometheus_remote_write_enabled          = var.remote_write_enabled
      prometheus_private_ip_bind               = var.private_ip_bind
      prometheus_memory_limit                  = var.memory_limit
      prometheus_memory_reservation            = var.memory_reservation
      prometheus_cpu_limit                     = var.cpu_limit
      prometheus_cpu_reservation               = var.cpu_reservation
      prometheus_timezone                      = var.timezone
      prometheus_diun_watch_enabled            = var.diun_watch_enabled
      prometheus_autoheal_enabled              = var.autoheal_enabled
      prometheus_blackbox_exporter_enabled     = var.blackbox_exporter_enabled
      prometheus_blackbox_exporter_image_tag   = var.blackbox_exporter_image_tag
      prometheus_blackbox_targets              = distinct(var.blackbox_targets)
      prometheus_tem_exporter_enabled          = var.tem_exporter_enabled
      prometheus_tem_smtp_secret_id            = var.tem_smtp_secret_id
      prometheus_tem_scaleway_project_id       = var.tem_scaleway_project_id
      prometheus_tem_scaleway_region           = var.tem_scaleway_region
      prometheus_tem_exporter_poll_interval    = var.tem_exporter_poll_interval_seconds
      prometheus_tem_exporter_lookback_minutes = var.tem_exporter_lookback_minutes
    }
  } : null
}

output "monitoring" {
  description = "Monitoring contribution. Currently surfaces the bundled Scaleway TEM dashboard when tem_exporter_enabled = true."
  value       = local.monitoring_contribution
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. `prometheus-data` is the TSDB — worth preserving across host loss so historical metrics survive."
  value = (var.enabled && var.backup_enabled) ? {
    id               = local.slug
    paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir          = true
    volumes          = ["prometheus-data"]
    excluded_volumes = []
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
  } : null
}
