# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Postiz is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID. null for non-forward-auth apps (Postiz is OIDC; this is the OIDC provider ID — do NOT add to identity's extra_forward_auth_provider_ids)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-postiz). Used by service accounts that need direct access."
  value       = var.enabled ? module.authentik[0].application_group_id : null
}

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value       = local.monitoring_contribution
}

# No inbound SG rules — every reachable port (UI + API) is fronted by Traefik
# on the existing public 443. Temporal + ES + redis + temporal-pg are all
# container-network-only.
output "required_inbound_rules" {
  description = "Security group rules required for this app to function. Empty for Postiz — Traefik fronts everything on the existing public ports."
  value       = []
}

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
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/postiz"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      postiz_hostname                         = var.hostname
      postiz_image_tag                        = var.image_tag
      postiz_temporal_image_tag               = var.temporal_image_tag
      postiz_temporal_elasticsearch_image_tag = var.temporal_elasticsearch_image_tag
      postiz_temporal_postgres_image_tag      = var.temporal_postgres_image_tag
      postiz_timezone                         = var.timezone
      postiz_disable_registration             = var.disable_registration
      postiz_app_secret_id                    = scaleway_secret.app[0].id
      postiz_db_credentials_secret_id         = module.database[0].secret_id
      postiz_smtp_secret_name                 = var.smtp_from_email == "" ? "" : "smtp-config"
      postiz_memory_limit                     = var.memory_limit
      postiz_memory_reservation               = var.memory_reservation
      postiz_cpu_limit                        = var.cpu_limit
      postiz_cpu_reservation                  = var.cpu_reservation
      postiz_es_heap_size                     = var.es_heap_size
      postiz_auto_update_enabled              = var.auto_update_enabled
      postiz_autoheal_enabled                 = var.autoheal_enabled
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Backs up /opt/postiz config + the postiz-uploads + postiz-config + temporal-postgres named volumes. Redis cache + ES index are intentionally excluded (cache + reindexable from temporal-postgres)."
  value = (var.enabled && var.backup_enabled) ? {
    id = local.slug
    paths = concat(
      [
        "/backup-sources/opt/${local.slug}",
        "/backup-sources/docker-volumes/${local.slug}_postiz-uploads/_data",
        "/backup-sources/docker-volumes/${local.slug}_postiz-config/_data",
        "/backup-sources/docker-volumes/${local.slug}_temporal-postgres-data/_data",
      ],
      var.backup_extra_paths,
    )
    excludes  = []
    schedule  = { cron = var.backup_schedule_cron }
    retention = var.backup_retention
  } : null
}

output "database_name" {
  description = "PostgreSQL database name (Postiz main DB, in Scaleway RDB). null when disabled. Temporal's metadata DB is in-stack and not exposed here."
  value       = var.enabled ? module.database[0].database_name : null
}
