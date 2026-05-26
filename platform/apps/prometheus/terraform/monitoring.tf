locals {
  monitoring_contribution = var.enabled ? {
    # No scrape contribution from the prometheus bundle itself — its own
    # /metrics endpoint scrape is wired in the role's prometheus.yml.j2.
    prometheus_scrape_configs = []
    # Ship the bundled Scaleway TEM dashboard when the exporter is on, and
    # the blackbox dashboard when the blackbox exporter is on. The role
    # drops paired alert rules onto disk; consumer picks up dashboards via
    # the grafana_dashboards aggregation.
    grafana_dashboards = concat(
      [
        "${path.module}/../monitoring/dashboards/infrastructure-overview.json",
        "${path.module}/../monitoring/dashboards/logs-explorer.json",
        "${path.module}/../monitoring/dashboards/traefik-overview.json",
      ],
      var.tem_exporter_enabled ? [
        "${path.module}/../monitoring/dashboards/scaleway-tem.json",
      ] : [],
      var.blackbox_exporter_enabled ? [
        "${path.module}/../monitoring/dashboards/blackbox.json",
      ] : [],
    )
    loki_log_paths   = []
    alert_rules      = []
    blackbox_targets = []
  } : null
}
