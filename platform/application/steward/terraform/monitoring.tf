locals {
  # Steward is a Django admin UI. No metrics endpoint of its own yet — just
  # ship container logs for now so the consumer aggregation has the shape
  # right when log shipping comes online.
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/steward-*.log",
    ]
    alert_rules      = []
    blackbox_targets = var.hostname != "" ? ["https://${var.hostname}/"] : []
  } : null
}
