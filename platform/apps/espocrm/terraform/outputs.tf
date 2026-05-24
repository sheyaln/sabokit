# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where EspoCRM is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID. null for non-forward-auth apps (EspoCRM is OIDC, so this is the OIDC provider ID — not bound to the embedded outpost)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-espocrm). Used by service accounts that need direct access."
  value       = var.enabled ? module.authentik[0].application_group_id : null
}

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value       = local.monitoring_contribution
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/role"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      espocrm_hostname                       = var.hostname
      espocrm_image_tag                      = var.image_tag
      espocrm_timezone                       = var.timezone
      espocrm_b2c_mode                       = var.b2c_mode
      espocrm_oidc_username_claim            = var.oidc_username_claim
      espocrm_oidc_group_claim               = var.oidc_group_claim
      espocrm_oidc_team_id_prefix            = var.oidc_team_id_prefix
      espocrm_oidc_group_role_mapping        = var.oidc_group_role_mapping
      espocrm_enable_member_entity_bootstrap = var.enable_member_entity_bootstrap
      espocrm_member_entity_webhooks         = var.member_entity_webhooks
      espocrm_app_secret_id                  = scaleway_secret.app[0].id
      espocrm_db_credentials_secret_id       = module.database[0].secret_id
      espocrm_auto_update_enabled            = var.auto_update_enabled
      espocrm_autoheal_enabled               = var.autoheal_enabled
    }
  } : null
}

output "database_name" {
  description = "PostgreSQL database name. null when disabled."
  value       = var.enabled ? module.database[0].database_name : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Aggregated by consumer-template into backrest's backup_plans."
  value = (var.enabled && var.backup_enabled) ? {
    id        = local.slug
    paths     = concat(["/backup-sources/opt/${local.slug}"], var.backup_extra_paths)
    excludes  = []
    schedule  = { cron = var.backup_schedule_cron }
    retention = var.backup_retention
  } : null
}
