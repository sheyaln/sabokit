locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/wazuh.manager-*.log",
      "/var/log/containers/wazuh.indexer-*.log",
      "/var/log/containers/wazuh.dashboard-*.log",
    ]
    alert_rules      = []
    blackbox_targets = var.hostname != "" ? ["https://${var.hostname}/"] : []
  } : null
}
