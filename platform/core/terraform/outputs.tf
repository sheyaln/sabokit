# What the core tier surfaces back to consumer-template. Per-service outputs
# are re-exposed so the stack module can flatten them into enabled_apps the
# same way it does for apps-tier modules, and the aggregation locals
# (backup plans, monitoring contribs, split-dns, inbound rules) can keep
# reading per-service.

output "core_apps" {
  description = "Per-service flattened {url, ansible_vars, ansible_group, monitoring, push_url} map. Consumer-template merges this into enabled_apps so the ansible playbook dispatch shape stays consistent."
  value = {
    loki = module.loki.enabled ? {
      ansible_vars  = module.loki.ansible.vars
      ansible_group = module.loki.ansible.host_group
      push_url      = module.loki.push_url
    } : null
    prometheus = module.prometheus.enabled ? {
      ansible_vars  = module.prometheus.ansible.vars
      ansible_group = module.prometheus.ansible.host_group
      monitoring    = module.prometheus.monitoring
    } : null
    grafana = module.grafana.enabled ? {
      url           = module.grafana.app_url
      ansible_vars  = module.grafana.ansible.vars
      ansible_group = module.grafana.ansible.host_group
      monitoring    = module.grafana.monitoring
    } : null
    wazuh = module.wazuh.enabled ? {
      url           = module.wazuh.app_url
      ansible_vars  = module.wazuh.ansible.vars
      ansible_group = module.wazuh.ansible.host_group
      monitoring    = module.wazuh.monitoring
    } : null
  }
}

# Aggregation contributions. Consumer-template's apps.tf reads these into
# its existing aggregated_* locals so per-app rolled-up scrape configs,
# alert rules, dashboards, backup plans, split-dns entries continue to
# include the core-tier services.

output "backup_plans" {
  description = "List of non-null backup_plan contributions from each enabled core-tier bundle. Flattened into local.aggregated_backup_plans alongside per-app contributions."
  value = [for plan in [
    module.loki.backup_plan,
    module.prometheus.backup_plan,
    module.grafana.backup_plan,
    module.wazuh.backup_plan,
  ] : plan if plan != null]
}

output "monitoring_contribs" {
  description = "List of non-null monitoring contributions (prometheus + grafana + wazuh; loki has none). Flattened into local._monitoring_contribs."
  value = [for c in [
    module.prometheus.monitoring,
    module.grafana.monitoring,
    module.wazuh.monitoring,
  ] : c if c != null]
}

output "split_dns_entries" {
  description = "Aggregated split-DNS contributions (public hostname -> private IP) from each core-tier bundle that exposes a hostname."
  value = concat(
    module.grafana.split_dns_entries,
    module.wazuh.split_dns_entries,
  )
}

output "required_inbound_rules" {
  description = "Security group rules required by core-tier bundles (wazuh manager ports — agents on every host reach the manager here). Aggregated into base.default_security_group_extra_inbound_rules."
  value       = module.wazuh.required_inbound_rules
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
    # Ports are consumer-supplied via var.core.wazuh.manager_*_port (re-echoed
    # here so host-services can read everything off module.core.wazuh).
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
