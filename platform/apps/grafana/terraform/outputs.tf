output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Grafana is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-grafana)."
  value       = var.enabled ? module.authentik[0].application_group_id : null
}

output "monitoring" {
  description = "Monitoring contribution."
  value       = local.monitoring_contribution
}

# Split-DNS contribution. Consumer-template merges every bundle's entries
# into the split_dns_overrides ansible var so each host resolves this
# hostname to the deployment host's private IP. Empty list when disabled.
output "split_dns_entries" {
  description = "Public-hostname -> private-IP overrides for cross-host resolution. Aggregated by the consumer-template."
  value = (var.enabled && var.hostname != "") ? [
    {
      hostname   = var.hostname
      private_ip = var.base.compute.hosts[var.deployment_host_key].private_ip
    },
  ] : []
}

output "ansible" {
  description = "Ansible deployment metadata."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/grafana"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      grafana_hostname                   = var.hostname
      grafana_image                      = var.image
      grafana_image_tag                  = var.image_tag
      grafana_plugins                    = var.plugins
      grafana_oidc_admin_group           = var.oidc_admin_group
      grafana_oidc_editor_group          = var.oidc_editor_group
      grafana_prometheus_url             = var.prometheus_url
      grafana_loki_url                   = var.loki_url
      grafana_prometheus_scrape_interval = var.prometheus_scrape_interval
      grafana_app_secret_id              = local.app_secret_id
      grafana_memory_limit               = var.memory_limit
      grafana_memory_reservation         = var.memory_reservation
      grafana_cpu_limit                  = var.cpu_limit
      grafana_cpu_reservation            = var.cpu_reservation
      grafana_auto_update_enabled        = var.auto_update_enabled
      grafana_autoheal_enabled           = var.autoheal_enabled
      grafana_dashboards                 = var.grafana_dashboards
      grafana_jsm_api_key_secret_id      = var.jsm_api_key_secret_id
      grafana_jsm_api_region             = var.jsm_api_region
      grafana_jsm_priority_mapping       = var.jsm_priority_mapping
      grafana_jsm_alert_tags             = var.jsm_alert_tags
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. `grafana-data` is `/var/lib/grafana` — internal sqlite holding user-created dashboards, alert rules, API keys, snapshots."
  value = (var.enabled && var.backup_enabled) ? {
    id               = local.slug
    paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir          = true
    volumes          = ["grafana-data"]
    excluded_volumes = []
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
  } : null
}
