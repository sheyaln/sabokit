locals {
  monitoring_contribution = var.enabled ? {
    # No scrape contribution from the prometheus bundle itself — its own
    # /metrics endpoint scrape is wired in the role's prometheus.yml.j2.
    prometheus_scrape_configs = []
    # Ship the bundled Scaleway TEM dashboard when the exporter is on. The
    # role already drops the alert rules onto disk; the consumer picks the
    # dashboard up via the grafana_dashboards aggregation.
    grafana_dashboards = var.tem_exporter_enabled ? [
      "${path.module}/../monitoring/dashboards/scaleway-tem.json",
    ] : []
    loki_log_paths = []
    alert_rules    = []
  } : null
}
