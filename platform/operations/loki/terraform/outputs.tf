# Contract outputs.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

# Loki push endpoint other bundles (monitoring-agent) wire into Alloy/Promtail.
# Falls back to the deployment host's private IP when the loki bundle isn't
# bound to a specific private_ip_bind. Empty when disabled.
output "push_url" {
  description = "URL Loki accepts pushes on. Wire this into monitoring-agent's monitoring_loki_push_url. null when disabled."
  value       = var.enabled ? "http://${coalesce(var.private_ip_bind, var.base.compute.hosts[var.deployment_host_key].private_ip)}:3100/loki/api/v1/push" : null
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
      loki_diun_watch_enabled      = var.diun_watch_enabled
      loki_autoheal_enabled        = var.autoheal_enabled
      loki_extra_env_vars          = var.extra_env_vars
      loki_extra_docker_networks   = var.extra_docker_networks
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. `loki-data` is the log archive (chunks + index)."
  value = (var.enabled && var.backup_enabled) ? {
    id               = local.slug
    paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir          = true
    volumes          = ["loki-data"]
    excluded_volumes = []
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
  } : null
}
