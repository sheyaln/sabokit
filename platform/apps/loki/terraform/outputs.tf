# Contract outputs.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/loki"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      loki_image                   = var.image
      loki_image_tag               = var.image_tag
      loki_retention               = var.retention
      loki_ingestion_rate_mb       = var.ingestion_rate_mb
      loki_ingestion_burst_size_mb = var.ingestion_burst_size_mb
      loki_private_ip_bind         = var.private_ip_bind
      loki_memory_limit            = var.memory_limit
      loki_memory_reservation      = var.memory_reservation
      loki_cpu_limit               = var.cpu_limit
      loki_cpu_reservation         = var.cpu_reservation
      loki_timezone                = var.timezone
      loki_auto_update_enabled     = var.auto_update_enabled
      loki_autoheal_enabled        = var.autoheal_enabled
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
