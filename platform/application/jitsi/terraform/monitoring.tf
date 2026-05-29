# Jitsi exposes Prometheus metrics on JVB (colibri stats endpoint) but the
# bundle doesn't currently wire scrape targets — JVB metrics are accessible
# only inside the meet.jitsi docker network, and exposing them safely requires
# either a sidecar or a fronting nginx with auth. Ship log paths for now and
# leave scrape configs empty; a future revision can add an exporter sidecar.

locals {
  monitoring_contribution = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths = [
      "/var/log/containers/jitsi-web-*.log",
      "/var/log/containers/jitsi-prosody-*.log",
      "/var/log/containers/jitsi-jicofo-*.log",
      "/var/log/containers/jitsi-jvb-*.log",
      "/var/log/containers/jitsi-oidc-adapter-*.log",
    ]
    alert_rules      = []
    blackbox_targets = var.hostname != "" ? ["https://${var.hostname}/"] : []
  } : null
}
