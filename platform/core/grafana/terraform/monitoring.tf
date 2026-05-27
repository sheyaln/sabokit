locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    # Grafana's metrics endpoint is on /metrics — scrape it from its own
    # Prometheus instance for self-observability (alerts on Grafana being
    # down would otherwise be invisible to itself).
    prometheus_scrape_configs = [
      {
        job_name = "grafana"
        static_configs = [
          { targets = ["grafana:3000"] },
        ]
      },
    ]
    grafana_dashboards = []
    loki_log_paths = [
      "/var/log/containers/grafana-*.log",
    ]
    alert_rules      = []
    blackbox_targets = var.hostname != "" ? ["https://${var.hostname}/api/health"] : []
  } : null
}
