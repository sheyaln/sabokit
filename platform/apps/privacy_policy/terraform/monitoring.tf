locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/privacy_policy-*.log",
    ]
    alert_rules = []
  } : null
}
