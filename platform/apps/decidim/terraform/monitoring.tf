# Decidim doesn't expose Prometheus metrics natively. Ship Loki log globs so
# request and Sidekiq logs land in the central logging stack when a Loki app
# is enabled; consumer-level aggregation drops null/[] safely.

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/decidim-*.log",
      "/var/log/containers/decidim-sidekiq-*.log",
      "/var/log/containers/decidim-redis-*.log",
    ]
    alert_rules = []
  } : null
}
