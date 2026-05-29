# Core-tier composition. Instantiates the monitoring/SIEM stack (loki,
# prometheus, grafana, wazuh) as a single tier between bootstrap and apps.
# Each sub-bundle is a host-singleton (one instance per env, typically on
# the management host) — plain module blocks, not per-host fan-outs.
#
# Tier philosophy: the category is non-optional (every consumer gets a
# place where logs/metrics/dashboards/alerts land), but each individual
# service is flippable via var.<svc>.enabled. Defaults are production-grade
# (every service on, deployment_host_key = "management").
#
# Cross-bundle wiring is folded in below so prometheus scrapes grafana's
# /metrics, grafana provisions prometheus's dashboards, etc. Each core
# bundle's own monitoring output feeds back into its siblings via the
# locals — no need to route through the consumer-template.

locals {
  # Core-tier self-wiring: grafana scrape, blackbox probes for grafana +
  # wazuh hostnames, loki log paths for the manager containers. We compute
  # these directly from var.* + sub-module input expressions rather than
  # reading module.<svc>.monitoring outputs — referencing a sibling
  # module's outputs would create a cycle (prometheus needs grafana's
  # scrape entries; grafana needs prometheus's dashboards).
  _grafana_hostname = try(var.grafana.hostname, "")
  _wazuh_hostname   = try(var.wazuh.hostname, "")

  _grafana_enabled    = try(var.grafana.enabled, true)
  _prometheus_enabled = try(var.prometheus.enabled, true)
  _wazuh_enabled      = try(var.wazuh.enabled, true)

  _self_scrape_configs = local._grafana_enabled ? [
    {
      job_name     = "grafana"
      scheme       = "http"
      metrics_path = "/metrics"
      static_configs = [
        { targets = ["grafana:3000"], labels = {} },
      ]
    },
  ] : []

  _self_alert_rules = []

  _self_blackbox_targets = distinct(concat(
    (local._grafana_enabled && local._grafana_hostname != "") ? ["https://${local._grafana_hostname}/api/health"] : [],
    (local._wazuh_enabled && local._wazuh_hostname != "") ? ["https://${local._wazuh_hostname}/"] : [],
  ))

  # Prometheus bundle ships dashboards under its monitoring/ directory.
  # Read them directly via path.module rather than module.prometheus.monitoring
  # to avoid a cross-module cycle (grafana <- prometheus.monitoring <-
  # prometheus <- grafana.monitoring <- grafana).
  _prom_dashboard_base = "${path.module}/../prometheus/monitoring/dashboards"
  _prom_dashboards_always = local._prometheus_enabled ? [
    "${local._prom_dashboard_base}/infrastructure-overview.json",
    "${local._prom_dashboard_base}/logs-explorer.json",
    "${local._prom_dashboard_base}/traefik-overview.json",
  ] : []
  _prom_dashboards_tem_exporter = (local._prometheus_enabled && try(var.prometheus.tem_exporter_enabled, false)) ? [
    "${local._prom_dashboard_base}/scaleway-tem.json",
  ] : []
  _prom_dashboards_blackbox = (local._prometheus_enabled && try(var.prometheus.blackbox_exporter_enabled, true)) ? [
    "${local._prom_dashboard_base}/blackbox.json",
  ] : []

  _self_dashboard_paths = concat(
    local._prom_dashboards_always,
    local._prom_dashboards_tem_exporter,
    local._prom_dashboards_blackbox,
  )

  _self_dashboards = [
    for p in local._self_dashboard_paths : {
      filename = basename(p)
      contents = file(p)
    }
  ]
}

module "loki" {
  source = "../loki/terraform"

  enabled = try(var.loki.enabled, true)
  base    = var.base

  deployment_host_key     = try(var.loki.deployment_host_key, "management")
  image                   = try(var.loki.image, "grafana/loki")
  image_tag               = try(var.loki.image_tag, "latest")
  retention               = try(var.loki.retention, "744h")
  ingestion_rate_mb       = try(var.loki.ingestion_rate_mb, 10)
  ingestion_burst_size_mb = try(var.loki.ingestion_burst_size_mb, 20)
  private_ip_bind         = try(var.loki.private_ip_bind, "")
  memory_limit            = try(var.loki.memory_limit, "1G")
  memory_reservation      = try(var.loki.memory_reservation, "256M")
  cpu_limit               = try(var.loki.cpu_limit, "1.0")
  cpu_reservation         = try(var.loki.cpu_reservation, "0.25")
  timezone                = try(var.loki.timezone, "UTC")
  diun_watch_enabled      = try(var.loki.diun_watch_enabled, true)
  autoheal_enabled        = try(var.loki.autoheal_enabled, true)
  backup_enabled          = try(var.loki.backup_enabled, true)
  backup_extra_paths      = try(var.loki.backup_extra_paths, ["/backup-sources/docker-volumes/loki_loki-data/_data"])
  backup_schedule_cron    = try(var.loki.backup_schedule_cron, "0 0 2 * * *")
  backup_retention        = try(var.loki.backup_retention, { daily = 7, weekly = 4, monthly = 12, yearly = 1 })
  extra_env_vars          = try(var.loki.extra_env_vars, {})
  extra_docker_networks   = try(var.loki.extra_docker_networks, [])
}

module "prometheus" {
  source = "../prometheus/terraform"

  enabled = try(var.prometheus.enabled, true)
  base    = var.base

  deployment_host_key  = try(var.prometheus.deployment_host_key, "management")
  image                = try(var.prometheus.image, "prom/prometheus")
  image_tag            = try(var.prometheus.image_tag, "latest")
  retention            = try(var.prometheus.retention, "30d")
  exporters_enabled    = try(var.prometheus.exporters_enabled, true)
  remote_write_enabled = try(var.prometheus.remote_write_enabled, true)
  private_ip_bind      = try(var.prometheus.private_ip_bind, "")

  # Apps-tier monitoring contribs come in via var.aggregated_*. Core-tier
  # bundles' own monitoring contributions (grafana + wazuh /metrics scrape
  # entries, dashboards) are folded in at the composition layer below via
  # local._core_self_contribs to avoid a cross-module reference cycle with
  # the consumer-template.
  scrape_configs   = concat(var.aggregated_scrape_configs, local._self_scrape_configs, try(var.prometheus.scrape_configs, []))
  alert_rules      = concat(var.aggregated_alert_rules, local._self_alert_rules, try(var.prometheus.alert_rules, []))
  blackbox_targets = concat(var.aggregated_blackbox_targets, local._self_blackbox_targets, try(var.prometheus.blackbox_targets, []))

  extra_scrape_targets = try(var.prometheus.extra_scrape_targets, {})

  blackbox_exporter_enabled   = try(var.prometheus.blackbox_exporter_enabled, true)
  blackbox_exporter_image_tag = try(var.prometheus.blackbox_exporter_image_tag, "v0.28.0")

  tem_exporter_enabled               = try(var.prometheus.tem_exporter_enabled, false)
  tem_smtp_secret_id                 = try(var.prometheus.tem_smtp_secret_id, "")
  tem_scaleway_project_id            = try(var.prometheus.tem_scaleway_project_id, "")
  tem_scaleway_region                = try(var.prometheus.tem_scaleway_region, "fr-par")
  tem_exporter_poll_interval_seconds = try(var.prometheus.tem_exporter_poll_interval_seconds, 60)
  tem_exporter_lookback_minutes      = try(var.prometheus.tem_exporter_lookback_minutes, 60)

  memory_limit          = try(var.prometheus.memory_limit, "2G")
  memory_reservation    = try(var.prometheus.memory_reservation, "512M")
  cpu_limit             = try(var.prometheus.cpu_limit, "2.0")
  cpu_reservation       = try(var.prometheus.cpu_reservation, "0.5")
  timezone              = try(var.prometheus.timezone, "UTC")
  diun_watch_enabled    = try(var.prometheus.diun_watch_enabled, true)
  autoheal_enabled      = try(var.prometheus.autoheal_enabled, true)
  backup_enabled        = try(var.prometheus.backup_enabled, true)
  backup_extra_paths    = try(var.prometheus.backup_extra_paths, ["/backup-sources/docker-volumes/prometheus_prometheus-data/_data"])
  backup_schedule_cron  = try(var.prometheus.backup_schedule_cron, "0 0 2 * * *")
  backup_retention      = try(var.prometheus.backup_retention, { daily = 7, weekly = 4, monthly = 12, yearly = 1 })
  extra_env_vars        = try(var.prometheus.extra_env_vars, {})
  extra_docker_networks = try(var.prometheus.extra_docker_networks, [])
}

module "grafana" {
  source = "../grafana/terraform"

  enabled  = try(var.grafana.enabled, true)
  hostname = try(var.grafana.hostname, "")
  base     = var.base


  authorized_groups   = try(var.grafana.authorized_groups, ["admin"])
  monitoring_enabled  = try(var.grafana.monitoring_enabled, true)
  deployment_host_key = try(var.grafana.deployment_host_key, "management")

  dns_zone_override = try(var.grafana.dns_zone_override, "")
  category_group    = try(var.grafana.category_group, "Technical Management")
  application_name  = try(var.grafana.application_name, "Grafana")
  application_slug  = try(var.grafana.application_slug, "")
  icon_url          = try(var.grafana.icon_url, "")
  icon_filename     = try(var.grafana.icon_filename, "grafana-icon.png")

  image          = try(var.grafana.image, "grafana/grafana")
  image_tag      = try(var.grafana.image_tag, "latest")
  admin_username = try(var.grafana.admin_username, "admin")
  plugins        = try(var.grafana.plugins, [])

  oidc_admin_group  = try(var.grafana.oidc_admin_group, "admin")
  oidc_editor_group = try(var.grafana.oidc_editor_group, "manager")

  prometheus_url             = try(var.grafana.prometheus_url, "http://prometheus:9090")
  loki_url                   = try(var.grafana.loki_url, "http://loki:3100")
  prometheus_scrape_interval = try(var.grafana.prometheus_scrape_interval, "30s")

  jsm_api_key_secret_id = try(var.grafana.jsm_api_key_secret_id, "")
  jsm_api_region        = try(var.grafana.jsm_api_region, "us")
  jsm_priority_mapping  = try(var.grafana.jsm_priority_mapping, { critical = "P1", warning = "P3", info = "P5" })
  jsm_alert_tags        = try(var.grafana.jsm_alert_tags, ["sabokit"])
  jsm_severity_gate     = try(var.grafana.jsm_severity_gate, "")

  grafana_dashboards = concat(
    var.aggregated_grafana_dashboards,
    local._self_dashboards,
    try(var.grafana.grafana_dashboards, []),
  )

  memory_limit          = try(var.grafana.memory_limit, "1G")
  memory_reservation    = try(var.grafana.memory_reservation, "256M")
  cpu_limit             = try(var.grafana.cpu_limit, "1.0")
  cpu_reservation       = try(var.grafana.cpu_reservation, "0.1")
  diun_watch_enabled    = try(var.grafana.diun_watch_enabled, true)
  autoheal_enabled      = try(var.grafana.autoheal_enabled, true)
  backup_enabled        = try(var.grafana.backup_enabled, true)
  backup_extra_paths    = try(var.grafana.backup_extra_paths, ["/backup-sources/docker-volumes/grafana_grafana-data/_data"])
  backup_schedule_cron  = try(var.grafana.backup_schedule_cron, "0 0 2 * * *")
  backup_retention      = try(var.grafana.backup_retention, { daily = 7, weekly = 4, monthly = 12, yearly = 1 })
  extra_env_vars        = try(var.grafana.extra_env_vars, {})
  extra_docker_networks = try(var.grafana.extra_docker_networks, [])
}

module "wazuh" {
  source = "../wazuh/terraform"

  enabled  = try(var.wazuh.enabled, true)
  hostname = try(var.wazuh.hostname, "")
  base     = var.base


  authorized_groups   = try(var.wazuh.authorized_groups, ["admin"])
  monitoring_enabled  = try(var.wazuh.monitoring_enabled, true)
  deployment_host_key = try(var.wazuh.deployment_host_key, "management")

  dns_zone_override = try(var.wazuh.dns_zone_override, "")
  category_group    = try(var.wazuh.category_group, "Technical Management")
  application_name  = try(var.wazuh.application_name, "Wazuh")
  application_slug  = try(var.wazuh.application_slug, "")
  icon_url          = try(var.wazuh.icon_url, "")
  icon_filename     = try(var.wazuh.icon_filename, "wazuh-icon.png")

  release_version     = try(var.wazuh.release_version, "4.9.0")
  oidc_admin_group    = try(var.wazuh.oidc_admin_group, "admin")
  oidc_readonly_group = try(var.wazuh.oidc_readonly_group, "")
  indexer_heap_size   = try(var.wazuh.indexer_heap_size, "1g")

  manager_agent_port      = try(var.wazuh.manager_agent_port, 1514)
  manager_enrollment_port = try(var.wazuh.manager_enrollment_port, 1515)
  manager_syslog_port     = try(var.wazuh.manager_syslog_port, 514)

  memory_limit       = try(var.wazuh.memory_limit, "2G")
  memory_reservation = try(var.wazuh.memory_reservation, "512M")
  cpu_limit          = try(var.wazuh.cpu_limit, "2.0")
  cpu_reservation    = try(var.wazuh.cpu_reservation, "0.5")
  diun_watch_enabled = try(var.wazuh.diun_watch_enabled, true)
  autoheal_enabled   = try(var.wazuh.autoheal_enabled, true)
  backup_enabled     = try(var.wazuh.backup_enabled, true)
  backup_extra_paths = try(var.wazuh.backup_extra_paths, [
    "/backup-sources/docker-volumes/wazuh_wazuh-indexer-data/_data",
    "/backup-sources/docker-volumes/wazuh_wazuh_etc/_data",
    "/backup-sources/docker-volumes/wazuh_wazuh_api_configuration/_data",
  ])
  backup_schedule_cron  = try(var.wazuh.backup_schedule_cron, "0 0 2 * * *")
  backup_retention      = try(var.wazuh.backup_retention, { daily = 7, weekly = 4, monthly = 12, yearly = 1 })
  extra_env_vars        = try(var.wazuh.extra_env_vars, {})
  extra_docker_networks = try(var.wazuh.extra_docker_networks, [])
}
