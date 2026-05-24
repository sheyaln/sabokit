# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this Watchtower instance is enabled."
  value       = var.enabled
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/watchtower"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      watchtower_image                       = var.image
      watchtower_image_tag                   = var.image_tag
      watchtower_schedule                    = var.schedule
      watchtower_label_enable                = var.label_enable
      watchtower_scope                       = var.scope
      watchtower_cleanup                     = var.cleanup
      watchtower_rolling_restart             = var.rolling_restart
      watchtower_include_stopped             = var.include_stopped
      watchtower_timezone                    = var.timezone
      watchtower_notifications_slack_webhook = var.notifications_slack_webhook
    }
  } : null
}
