# Identity (Authentik) monitoring contribution. Same shape as the app-bundle
# monitoring outputs so the consumer-template's _monitoring_contribs aggregation
# picks these up alongside every app's contribution.
#
# The alert rules below target Authentik's stock Prometheus metrics
# (authentik_app job). They assume a scrape config exists in the consumer's
# topology — the consumer-template adds it via the cross-host scrape knob on
# the prometheus bundle. Disabling monitoring_enabled emits null so the
# aggregator skips this contribution.

variable "monitoring_enabled" {
  description = "Emit the identity bundle's monitoring contribution (Prometheus alert rules for Authentik availability/latency/login health). Default true. Set false to suppress when the consumer manages identity alerts out of band."
  type        = bool
  default     = true
}

locals {
  monitoring_contribution = var.monitoring_enabled ? {
    prometheus_scrape_configs = []
    grafana_dashboards        = []
    loki_log_paths            = []
    alert_rules = [
      {
        name     = "authentik-availability"
        interval = "30s"
        rules = [
          {
            alert = "AuthentikServiceDown"
            expr  = "up{job=\"authentik-app\"} < 1"
            for   = "1m"
            labels = {
              severity = "critical"
              service  = "authentik"
              type     = "availability"
            }
            annotations = {
              summary     = "Authentik service unavailable"
              description = "Authentik service is down or not responding to health checks."
            }
          },
        ]
      },
      {
        name     = "authentik-latency"
        interval = "60s"
        rules = [
          {
            alert = "AuthentikHighLatency"
            expr  = "histogram_quantile(0.95, rate(authentik_flow_execution_duration_seconds_bucket{job=\"authentik-app\"}[5m])) > 3"
            for   = "5m"
            labels = {
              severity = "warning"
              service  = "authentik"
              type     = "performance"
            }
            annotations = {
              summary     = "High authentication latency detected"
              description = "Authentik 95th-percentile flow execution latency is above 3s (value {{ $value }}s)."
            }
          },
        ]
      },
      {
        name     = "authentik-login-failures"
        interval = "60s"
        rules = [
          {
            alert = "AuthentikHighLoginFailureRate"
            expr  = "rate(authentik_events_total{job=\"authentik-app\", action=\"login_failed\"}[5m]) * 60 > 5"
            for   = "5m"
            labels = {
              severity = "warning"
              service  = "authentik"
              type     = "authentication"
            }
            annotations = {
              summary     = "High authentication failure rate detected"
              description = "Authentik is experiencing more than 5 failed logins per minute (value {{ $value }})."
            }
          },
        ]
      },
      {
        name     = "authentik-success-rate"
        interval = "60s"
        rules = [
          {
            alert = "AuthentikLowSuccessRate"
            expr  = "(rate(authentik_events_total{job=\"authentik-app\", action=\"login\"}[5m]) / (rate(authentik_events_total{job=\"authentik-app\", action=\"login\"}[5m]) + rate(authentik_events_total{job=\"authentik-app\", action=\"login_failed\"}[5m]))) * 100 < 95"
            for   = "10m"
            labels = {
              severity = "critical"
              service  = "authentik"
              type     = "authentication"
            }
            annotations = {
              summary     = "Low authentication success rate detected"
              description = "Authentik login success rate is below 95% (value {{ $value }}%)."
            }
          },
        ]
      },
    ]
    blackbox_targets = []
  } : null
}

output "monitoring" {
  description = "Monitoring contribution (Prometheus alert rules + log paths). Same shape as the app-bundle monitoring outputs; the consumer-template aggregates this into prometheus + grafana + loki bundle inputs."
  value       = local.monitoring_contribution
}
