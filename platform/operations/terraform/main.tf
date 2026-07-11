# Operations-tier composition. Instantiates the monitoring/SIEM stack (loki,
# prometheus, grafana, wazuh) as one layer. Each sub-bundle is a host-singleton
# (one instance per env, typically on the ops host) — plain module blocks, not
# per-host fan-outs.
#
# Tier philosophy: the category is non-optional (every consumer gets a place
# where logs/metrics/dashboards/alerts land), but each individual service is
# flippable via var.<svc>.enabled. Defaults are production-grade (every service
# on, deployment_host_key = "management").
#
# Cross-bundle wiring is folded into the locals below so prometheus scrapes
# grafana's /metrics, grafana provisions prometheus's dashboards, etc. — each
# bundle's own monitoring is computed from var.* + path.module rather than read
# off a sibling module's output, which would cycle.

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

  # base64 the JSON so the raw file crosses the TF -> ansible boundary intact.
  # Grafana dashboards embed Prometheus legend syntax ({{server}}, {{instance}});
  # a b64decode result is not re-templated by Ansible, so those braces survive
  # instead of being evaluated as undefined Jinja vars.
  _self_dashboards = [
    for p in local._self_dashboard_paths : {
      filename     = basename(p)
      contents_b64 = base64encode(file(p))
    }
  ]
}

# The data-source contract: rebuilds `base` ({scaleway, compute, domains,
# authentik}) from the infra + identity layers by name/tag — no remote_state.
# Every sub-bundle consumes module.base.base as its var.base. The authentik
# provider this module's data.authentik_* lookups need is configured at the
# consumer root (from the ${org}-${env}-authentik-admin secret) and inherited
# here.
module "base" {
  source = "../../_shared/contract"

  org_slug    = var.org_slug
  environment = var.environment

  scaleway_project_id = var.scaleway_project_id
  scaleway_region     = var.scaleway_region
  scaleway_zone       = var.scaleway_zone

  private_network_subnet = var.private_network_subnet
  postgres_enabled       = var.postgres_enabled
  postgres_engine        = var.postgres_engine

  base_domain     = var.base_domain
  mgmt_domain     = var.mgmt_domain
  identity_domain = var.identity_domain

  smtp_secret_name = var.smtp_secret_name
  icon_base_url    = var.icon_base_url
  group_names      = var.group_names

  # Project the consumer's full compute_hosts to the role/ansible subset the
  # contract's object type accepts.
  compute_hosts = {
    for k, h in var.compute_hosts : k => {
      role           = h.role
      ansible_group  = try(h.ansible_group, "")
      ansible_groups = try(h.ansible_groups, [])
    }
  }
}

module "loki" {
  source = "../loki/terraform"

  enabled = try(var.loki.enabled, true)
  base    = module.base.base

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
  base    = module.base.base

  deployment_host_key  = try(var.prometheus.deployment_host_key, "management")
  image                = try(var.prometheus.image, "prom/prometheus")
  image_tag            = try(var.prometheus.image_tag, "latest")
  retention            = try(var.prometheus.retention, "30d")
  exporters_enabled    = try(var.prometheus.exporters_enabled, true)
  remote_write_enabled = try(var.prometheus.remote_write_enabled, true)
  private_ip_bind      = try(var.prometheus.private_ip_bind, "")

  # v1.0: no cross-layer aggregation. Per-app scrape/alert/blackbox contribs
  # arrive at deploy time via Alloy remote_write / ansible push to this host,
  # not a TF input (dropped var.aggregated_*). What stays is this layer's OWN
  # self-wiring (grafana + wazuh /metrics) + the consumer's explicit overrides.
  scrape_configs   = concat(local._self_scrape_configs, try(var.prometheus.scrape_configs, []))
  alert_rules      = concat(local._self_alert_rules, try(var.prometheus.alert_rules, []))
  blackbox_targets = concat(local._self_blackbox_targets, try(var.prometheus.blackbox_targets, []))

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
  base     = module.base.base


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

  # v1.0: no var.aggregated_grafana_dashboards — per-app dashboards land via
  # ansible push to grafana's provisioning dir at deploy time. This layer's own
  # dashboards (_self_dashboards) + consumer overrides remain TF-managed.
  # Overrides supplied via var.grafana.grafana_dashboards must carry
  # {filename, contents_b64} (base64encode the JSON so legend braces survive).
  grafana_dashboards = concat(
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
  base     = module.base.base


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

# ProtonMail Bridge — IMAP gateway apps fetch mail through (n8n inbox polling).
# OFF by default; needs enabled + imap_username + bridge_login_secret_id.
module "protonmail_bridge" {
  source = "../protonmail-bridge/terraform"

  enabled = try(var.protonmail_bridge.enabled, false)
  base    = module.base.base

  # imap_username + bridge_login_secret_id are required when enabled; the try()
  # placeholders keep the module type-checking when disabled (the bundle's count
  # gating means they're never consumed in that case).
  imap_username          = try(var.protonmail_bridge.imap_username, "")
  bridge_login_secret_id = try(var.protonmail_bridge.bridge_login_secret_id, "")

  deployment_host_key     = try(var.protonmail_bridge.deployment_host_key, "management")
  image_tag               = try(var.protonmail_bridge.image_tag, "latest")
  timezone                = try(var.protonmail_bridge.timezone, "UTC")
  imap_config_secret_name = try(var.protonmail_bridge.imap_config_secret_name, "imap-config")
  diun_watch_enabled      = try(var.protonmail_bridge.diun_watch_enabled, false)
  autoheal_enabled        = try(var.protonmail_bridge.autoheal_enabled, true)
  extra_env_vars          = try(var.protonmail_bridge.extra_env_vars, {})
  extra_docker_networks   = try(var.protonmail_bridge.extra_docker_networks, [])
}
