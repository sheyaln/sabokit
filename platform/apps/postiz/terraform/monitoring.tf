# Postiz exposes no Prometheus /metrics endpoint of its own — scrape configs
# are empty. Log paths feed Loki via the standard /var/log/containers/<name>-*
# pattern Alloy/Promtail already scrapes; the temporal sidecars are covered
# too. A future enhancement could add a Prometheus exporter sidecar but
# that's out of scope for v1 of this bundle.

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/postiz-*.log",
      "/var/log/containers/postiz-redis-*.log",
      "/var/log/containers/temporal-*.log",
    ]
    alert_rules = []
  } : null
}
