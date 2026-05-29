output "enabled" {
  description = "Whether this bootstrap-mail-imap bundle is enabled."
  value       = var.enabled
}

output "imap_config_secret_id" {
  description = "ID of the Scaleway secret apps consume for IMAP credentials. null when disabled. Apps reference by NAME (default `imap-config`)."
  value       = var.enabled ? scaleway_secret.imap_config[0].id : null
}

output "imap_endpoint" {
  description = "Connection info for diagnostics. Container is reachable on the docker network as `protonmail-bridge:143`. null when disabled."
  value = var.enabled ? {
    host    = "protonmail-bridge"
    port    = 143
    use_tls = "starttls"
  } : null
}

output "ansible" {
  description = "Ansible deployment metadata."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/protonmail-bridge"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      protonmail_bridge_image                 = var.image
      protonmail_bridge_image_tag             = var.image_tag
      protonmail_bridge_timezone              = var.timezone
      protonmail_bridge_memory_limit          = var.memory_limit
      protonmail_bridge_memory_reservation    = var.memory_reservation
      protonmail_bridge_cpu_limit             = var.cpu_limit
      protonmail_bridge_cpu_reservation       = var.cpu_reservation
      protonmail_bridge_diun_watch_enabled    = var.diun_watch_enabled
      protonmail_bridge_autoheal_enabled      = var.autoheal_enabled
      protonmail_bridge_extra_env_vars        = var.extra_env_vars
      protonmail_bridge_extra_docker_networks = var.extra_docker_networks
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution."
  value = (var.enabled && var.backup_enabled) ? {
    id        = local.slug
    paths     = concat(["/backup-sources/opt/${local.slug}"], var.backup_extra_paths)
    excludes  = []
    schedule  = { cron = var.backup_schedule_cron }
    retention = var.backup_retention
  } : null
}
