# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Nextcloud is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID. Nextcloud speaks OIDC; not bound to the embedded outpost."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-nextcloud). Used by service accounts (e.g. n8n) that need direct access."
  value       = var.enabled ? module.authentik[0].application_group_id : null
}

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value       = local.monitoring_contribution
}

# Talk HPB needs TURN (3478 TCP+UDP) + a UDP relay range for media. Returned
# only when talk_hostname is set (i.e. Talk HPB is actually being deployed) so
# disabling Talk closes the ports automatically. Aggregated by the consumer-
# template into base's default security group.
output "required_inbound_rules" {
  description = "Security group rules required for this app to function. Aggregated by the consumer-template into base's default_security_group_extra_inbound_rules."
  value = (var.enabled && var.talk_hostname != "") ? [
    {
      protocol   = "TCP"
      port       = var.talk_turn_port
      port_range = "${var.talk_turn_port}-${var.talk_turn_port}"
      ip_range   = "0.0.0.0/0"
    },
    {
      protocol   = "UDP"
      port       = var.talk_turn_port
      port_range = "${var.talk_turn_port}-${var.talk_turn_port}"
      ip_range   = "0.0.0.0/0"
    },
    {
      protocol   = "UDP"
      port       = null
      port_range = "${var.talk_relay_port_min}-${var.talk_relay_port_max}"
      ip_range   = "0.0.0.0/0"
    },
  ] : []
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/roles/nextcloud"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      nextcloud_hostname                 = var.hostname
      nextcloud_image_tag                = var.image_tag
      nextcloud_app_secret_id            = scaleway_secret.app[0].id
      nextcloud_db_credentials_secret_id = module.database[0].secret_id
      # SMTP is opt-in: empty smtp_from_email means SMTP is off and the role
      # skips the lookup entirely.
      nextcloud_smtp_secret_name = var.smtp_from_email == "" ? "" : "smtp-config"

      # Instance identity + scheduling + app management.
      nextcloud_instance_name            = var.instance_name
      nextcloud_maintenance_window_start = var.maintenance_window_start
      nextcloud_enabled_apps             = var.enabled_apps
      nextcloud_disabled_apps            = var.disabled_apps
      nextcloud_n8n_form_webhook_url     = var.n8n_form_webhook_url

      # OnlyOffice + Talk HPB knobs that aren't secret-shaped (image tags,
      # resource caps, port ranges). Secret-shaped values travel through the
      # single app-secrets bag above.
      nextcloud_onlyoffice_hostname     = var.onlyoffice_hostname
      nextcloud_onlyoffice_image_tag    = var.onlyoffice_image_tag
      nextcloud_onlyoffice_memory_limit = var.onlyoffice_memory_limit
      nextcloud_onlyoffice_cpu_limit    = var.onlyoffice_cpu_limit

      nextcloud_talk_hostname       = var.talk_hostname
      nextcloud_talk_image_tag      = var.talk_image_tag
      nextcloud_talk_turn_port      = var.talk_turn_port
      nextcloud_talk_relay_port_min = var.talk_relay_port_min
      nextcloud_talk_relay_port_max = var.talk_relay_port_max
      nextcloud_talk_memory_limit   = var.talk_memory_limit
      nextcloud_talk_cpu_limit      = var.talk_cpu_limit
    }
  } : null
}

# Convenience outputs for cross-app integrations or admin tooling.

output "data_bucket_name" {
  description = "Name of the S3 bucket used as primary storage. null when disabled."
  value       = var.enabled ? module.data_bucket[0].name : null
}

output "database_name" {
  description = "PostgreSQL database name. null when disabled."
  value       = var.enabled ? module.database[0].database_name : null
}
