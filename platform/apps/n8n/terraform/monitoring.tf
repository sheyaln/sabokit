# n8n exposes Prometheus metrics under /metrics only when N8N_METRICS=true.
# We default that to off (see env.j2) because metrics include workflow names
# which can leak operational info; enable on the consumer side by overriding
# the role var n8n_metrics_enabled and adding a scrape config here.
#
# Contribution is log paths + (nothing else by default).

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/n8n-*.log",
      "/var/log/containers/n8n-runners-*.log",
    ]
    alert_rules = []
  } : null
}
