# Contract outputs (every app bundle has these). See ARCHITECTURE.md.

output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where Jitsi is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

output "authentik_provider_id" {
  description = "OIDC provider ID. null for non-forward-auth apps (Jitsi authenticates via the OIDC adapter, not the embedded outpost — don't add this to extra_forward_auth_provider_ids)."
  value       = var.enabled ? module.authentik[0].provider_id : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group (app-jitsi). Used by service accounts that need direct access."
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
      jitsi_hostname              = var.hostname
      jitsi_image_tag             = var.image_tag
      jitsi_timezone              = var.timezone
      jitsi_jvb_udp_port          = var.jvb_udp_port
      jitsi_jvb_stun_servers      = var.jvb_stun_servers
      jitsi_enable_lobby          = var.enable_lobby
      jitsi_enable_breakout_rooms = var.enable_breakout_rooms
      jitsi_enable_prejoin_page   = var.enable_prejoin_page
      jitsi_oidc_adapter_repo     = var.oidc_adapter_image_repo
      jitsi_oidc_adapter_version  = var.oidc_adapter_image_version
      jitsi_oidc_log_level        = var.oidc_log_level
      jitsi_authentik_gateway     = var.base.authentik.gateway_domain
      jitsi_app_secret_id         = scaleway_secret.app[0].id
    }
  } : null
}
