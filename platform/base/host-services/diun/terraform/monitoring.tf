# Diun does not expose /metrics natively. The separate crazy-max/diun-exporter
# project (experimental) could fill that gap later — out of scope for v1.
# Loki picks up the container logs, which is where new-image events land
# when no notifiers are configured.

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/${local.qualified_slug}-*.log",
    ]
    alert_rules      = []
    blackbox_targets = []
  } : null
}
