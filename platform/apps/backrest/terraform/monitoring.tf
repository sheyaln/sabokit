# Backrest exposes Prometheus metrics on the same HTTP port (9898) at
# /metrics. The scrape target is the container, not the public hostname,
# so the consumer's prometheus app reaches it over the shared Docker
# network (assumes Prometheus runs on the same host as this instance).

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = [
      {
        job_name     = "backrest-${var.instance_name}"
        scheme       = "http"
        metrics_path = "/metrics"
        static_configs = [{
          targets = ["backrest-${var.instance_name}:9898"]
          labels = {
            instance = var.instance_name
          }
        }]
      }
    ]
    grafana_dashboards = []
    loki_log_paths = [
      "/var/log/containers/backrest-${var.instance_name}-*.log",
    ]
    alert_rules = []
  } : null
}
