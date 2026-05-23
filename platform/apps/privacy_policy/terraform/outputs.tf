output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where the privacy policy is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

# Privacy-policy is public — no Authentik provider or per-app group.

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value       = local.monitoring_contribution
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/role"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      privacy_policy_hostname   = var.hostname
      privacy_policy_page_title = var.page_title
    }
  } : null
}
