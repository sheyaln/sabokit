# What the operations layer surfaces. core_apps is the per-service enabled_apps
# dispatch the layer's own ansible consumes; the per-service handles below are
# read by callers needing a specific service's address/ids. v1.0 has NO
# cross-layer aggregation outputs — per-app monitoring/backup move to ansible
# push, split-dns is config-derived, and the SG inbound superset is static in
# infra — so the old backup_plans/monitoring_contribs/split_dns_entries/
# required_inbound_rules outputs are gone.

output "core_apps" {
  description = "Per-service flattened {url, ansible_vars, ansible_group, monitoring, push_url, backup_plan} map. Surfaced as the operations layer's enabled_apps so the ansible playbook dispatch shape stays consistent."
  value = {
    loki = module.loki.enabled ? {
      ansible_vars  = module.loki.ansible.vars
      ansible_group = module.loki.ansible.host_group
      push_url      = module.loki.push_url
      backup_plan   = module.loki.backup_plan
    } : null
    prometheus = module.prometheus.enabled ? {
      ansible_vars  = module.prometheus.ansible.vars
      ansible_group = module.prometheus.ansible.host_group
      monitoring    = module.prometheus.monitoring
      backup_plan   = module.prometheus.backup_plan
    } : null
    grafana = module.grafana.enabled ? {
      url           = module.grafana.app_url
      ansible_vars  = module.grafana.ansible.vars
      ansible_group = module.grafana.ansible.host_group
      monitoring    = module.grafana.monitoring
      backup_plan   = module.grafana.backup_plan
    } : null
    wazuh = module.wazuh.enabled ? {
      url           = module.wazuh.app_url
      ansible_vars  = module.wazuh.ansible.vars
      ansible_group = module.wazuh.ansible.host_group
      monitoring    = module.wazuh.monitoring
      backup_plan   = module.wazuh.backup_plan
    } : null
    protonmail_bridge = module.protonmail_bridge.enabled ? {
      ansible_vars  = module.protonmail_bridge.ansible.vars
      ansible_group = module.protonmail_bridge.ansible.host_group
      backup_plan   = module.protonmail_bridge.backup_plan
    } : null
  }
}

# Service-specific handles other tiers / host-services consume directly.

output "loki" {
  description = "Loki bundle handles. push_url is what the base monitoring-agent role wires into Alloy."
  value = {
    enabled  = module.loki.enabled
    push_url = module.loki.push_url
  }
}

output "wazuh" {
  description = "Wazuh manager handles. The host-services wazuh-agent bundle reads manager_private_ip + the listening ports for agent enrollment + log forwarding. manager_private_ip is null until the wazuh bundle's outputs.tf adds it (peer ticket: move-wazuh-agent-to-host-services)."
  value = {
    enabled               = module.wazuh.enabled
    authentik_provider_id = module.wazuh.authentik_provider_id
    manager_private_ip    = try(module.wazuh.manager_private_ip, null)
    # Ports are consumer-supplied via var.wazuh.manager_*_port (re-echoed here
    # so host-services can read everything off the operations wazuh output).
    manager_agent_port      = try(var.wazuh.manager_agent_port, 1514)
    manager_enrollment_port = try(var.wazuh.manager_enrollment_port, 1515)
    manager_syslog_port     = try(var.wazuh.manager_syslog_port, 514)
  }
}

output "grafana" {
  description = "Grafana bundle handles."
  value = {
    enabled                        = module.grafana.enabled
    authentik_provider_id          = module.grafana.authentik_provider_id
    authentik_application_group_id = module.grafana.authentik_application_group_id
  }
}

output "prometheus" {
  description = "Prometheus bundle handles."
  value = {
    enabled = module.prometheus.enabled
  }
}
