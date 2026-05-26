output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where the Wazuh dashboard is reachable."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "Authentik OIDC provider ID. Wazuh uses native OIDC via opensearch-security — does NOT belong in identity's extra_forward_auth_provider_ids (that list is for proxy-providers only). Exposed for any consumer tooling that needs the provider handle directly."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-wazuh)."
  value       = var.enabled ? module.authentik[0].application_group_id : null
}

output "monitoring" {
  description = "Monitoring contribution (log paths only)."
  value       = local.monitoring_contribution
}

# Wazuh agents on every monitored host need to reach the manager on
# TCP 1514 + 1515 + UDP 514. The bundle declares those automatically
# when enabled. Manager API (55000) stays internal.
output "required_inbound_rules" {
  description = "Security group rules required for agents to reach the manager. Aggregated by consumer-template into base.default_security_group_extra_inbound_rules."
  value = var.enabled ? [
    {
      protocol   = "TCP"
      port       = var.manager_agent_port
      port_range = "${var.manager_agent_port}-${var.manager_agent_port}"
      ip_range   = "0.0.0.0/0"
    },
    {
      protocol   = "TCP"
      port       = var.manager_enrollment_port
      port_range = "${var.manager_enrollment_port}-${var.manager_enrollment_port}"
      ip_range   = "0.0.0.0/0"
    },
    {
      protocol   = "UDP"
      port       = var.manager_syslog_port
      port_range = "${var.manager_syslog_port}-${var.manager_syslog_port}"
      ip_range   = "0.0.0.0/0"
    },
  ] : []
}

# Split-DNS contribution. Consumer-template merges every bundle's entries
# into the split_dns_overrides ansible var so each host resolves this
# hostname to the deployment host's private IP. Empty list when disabled.
output "split_dns_entries" {
  description = "Public-hostname -> private-IP overrides for cross-host resolution. Aggregated by the consumer-template."
  value = (var.enabled && var.hostname != "") ? [
    {
      hostname   = var.hostname
      private_ip = var.base.compute.hosts[var.deployment_host_key].private_ip
    },
  ] : []
}

output "ansible" {
  description = "Ansible deployment metadata."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/wazuh"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      wazuh_hostname                = var.hostname
      wazuh_version                 = var.release_version
      wazuh_indexer_heap_size       = var.indexer_heap_size
      wazuh_manager_agent_port      = var.manager_agent_port
      wazuh_manager_enrollment_port = var.manager_enrollment_port
      wazuh_manager_syslog_port     = var.manager_syslog_port
      wazuh_app_secret_id           = local.app_secret_id
      wazuh_oidc_admin_group        = var.oidc_admin_group
      wazuh_oidc_readonly_group     = var.oidc_readonly_group
      wazuh_memory_limit            = var.memory_limit
      wazuh_memory_reservation      = var.memory_reservation
      wazuh_cpu_limit               = var.cpu_limit
      wazuh_cpu_reservation         = var.cpu_reservation
      wazuh_diun_watch_enabled      = var.diun_watch_enabled
      wazuh_autoheal_enabled        = var.autoheal_enabled
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Indexer is the SIEM event store; `wazuh_etc` / `wazuh_api_configuration` carry the manager's rules, decoders, agent registry; queues + active-response + wodles + filebeat state survive restarts. `wazuh_logs` is excluded — those are also shipped to Loki."
  value = (var.enabled && var.backup_enabled) ? {
    id      = local.slug
    paths   = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir = true
    volumes = [
      "wazuh-indexer-data",
      "wazuh_api_configuration",
      "wazuh_etc",
      "wazuh_queue",
      "wazuh_var_multigroups",
      "wazuh_active_response",
      "wazuh_wodles",
      "filebeat_etc",
      "filebeat_var",
      "wazuh-dashboard-custom",
    ]
    excluded_volumes = ["wazuh_logs"]
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
  } : null
}
