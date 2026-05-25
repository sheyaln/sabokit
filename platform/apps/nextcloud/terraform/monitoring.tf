# Nextcloud exposes /ocs/v2.php/apps/serverinfo/api/v1/info for metrics but
# it's gated behind admin auth, not a Prometheus-friendly endpoint. Ship log
# paths only — a serverinfo exporter would belong in apps/prometheus once
# someone wires it up.
locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/nextcloud-*.log",
      "/var/log/containers/nextcloud-redis-*.log",
      "/var/log/containers/nextcloud-cron-*.log",
      "/var/log/containers/nextcloud-onlyoffice-*.log",
      "/var/log/containers/nextcloud-talk-*.log",
    ]
    alert_rules = []
    # Three public hostnames — main UI, OnlyOffice editor, Talk HPB signaling.
    # Probe each; any one down breaks a different bit of the user experience.
    blackbox_targets = compact([
      var.hostname != "" ? "https://${var.hostname}/status.php" : "",
      var.onlyoffice_hostname != "" ? "https://${var.onlyoffice_hostname}/healthcheck" : "",
      var.talk_hostname != "" ? "https://${var.talk_hostname}/api/v1/welcome" : "",
    ])
  } : null
}
