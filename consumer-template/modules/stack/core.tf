# Core-tier composition. Logs (Loki), metrics (Prometheus), dashboards +
# alerting (Grafana), SIEM (Wazuh manager) — sibling to module.base /
# module.identity / module.bootstrap. Defaults to fully on; flip individual
# services off via var.core.<svc>.enabled = false.

module "core" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/core/terraform?ref=v0.1.0"

  base = local.base

  loki       = try(var.core.loki, {})
  prometheus = try(var.core.prometheus, {})
  grafana    = try(var.core.grafana, {})
  wazuh      = try(var.core.wazuh, {})

  # Auto-aggregated from every enabled app's monitoring contribution.
  # The locals below are defined in apps.tf alongside the apps-tier
  # aggregation; core consumes them just like the prometheus + grafana
  # module blocks did when they lived in apps.tf.
  aggregated_scrape_configs     = local.aggregated_scrape_configs
  aggregated_alert_rules        = local.aggregated_alert_rules
  aggregated_blackbox_targets   = local.aggregated_blackbox_targets
  aggregated_grafana_dashboards = local.aggregated_grafana_dashboards
}
