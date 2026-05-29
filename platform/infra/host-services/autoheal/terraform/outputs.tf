# Contract outputs.

output "enabled" {
  description = "Whether this Autoheal instance is enabled."
  value       = var.enabled
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/autoheal"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      autoheal_image                = var.image
      autoheal_image_tag            = var.image_tag
      autoheal_container_label      = var.container_label
      autoheal_interval_seconds     = var.interval_seconds
      autoheal_start_period_seconds = var.start_period_seconds
      autoheal_timezone             = var.timezone
    }
  } : null
}
