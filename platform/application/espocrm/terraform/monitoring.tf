# EspoCRM doesn't expose Prometheus metrics. Contribution is the container log
# stream (Loki) and whatever the Traefik service dashboard captures.

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/espocrm-*.log",
      "/var/log/containers/espocrm-daemon-*.log",
    ]
    alert_rules      = []
    blackbox_targets = var.hostname != "" ? ["https://${var.hostname}/"] : []
  } : null
}
