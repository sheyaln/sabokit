# Outline doesn't expose Prometheus metrics out of the box, so the scrape
# contribution is empty. We still ship a dashboard for log-based metrics
# (via Loki) and a Traefik service dashboard for the router.
#
# The aggregation at the consumer level coalesces null/[] returns harmlessly.

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards = [
      "${path.module}/../monitoring/dashboards/outline-traefik.json",
    ]
    loki_log_paths = [
      "/var/log/containers/outline-*.log",
      "/var/log/containers/outline-redis-*.log",
    ]
    alert_rules      = []
    blackbox_targets = var.hostname != "" ? ["https://${var.hostname}/"] : []
  } : null
}
