output "enabled" {
  description = "Whether this agent instance is enabled."
  value       = var.enabled
}

output "ansible" {
  description = "Ansible deployment metadata."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/wazuh-agent"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      wazuh_agent_image               = var.image
      wazuh_agent_release_version     = var.release_version
      wazuh_agent_name                = var.agent_name != "" ? var.agent_name : var.deployment_host_key
      wazuh_agent_manager_address     = var.manager_address
      wazuh_agent_auto_update_enabled = var.auto_update_enabled
      wazuh_agent_autoheal_enabled    = var.autoheal_enabled
    }
  } : null
}
