# Vikunja doesn't expose Prometheus metrics in a useful way out of the box.
# Contribution is log paths + the Traefik service dashboard.

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/vikunja-*.log",
    ]
    alert_rules      = []
    blackbox_targets = var.hostname != "" ? ["https://${var.hostname}/"] : []
  } : null
}
