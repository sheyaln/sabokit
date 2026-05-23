# BentoPDF doesn't expose metrics. Contribution is log paths only.

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/bentopdf-*.log",
    ]
    alert_rules = []
  } : null
}
