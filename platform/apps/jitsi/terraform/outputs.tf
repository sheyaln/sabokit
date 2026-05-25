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

# Rules the consumer-template aggregates into base's default security group
# so JVB's UDP media port is reachable globally without the consumer
# touching the SG themselves. Empty when disabled.
output "required_inbound_rules" {
  description = "Security group rules required for this app to function. Aggregated by the consumer-template into base's default_security_group_extra_inbound_rules."
  value = var.enabled ? [
    {
      protocol   = "UDP"
      port       = var.jvb_udp_port
      port_range = "${var.jvb_udp_port}-${var.jvb_udp_port}"
      ip_range   = "0.0.0.0/0"
    },
  ] : []
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
      jitsi_auto_update_enabled   = var.auto_update_enabled
      jitsi_autoheal_enabled      = var.autoheal_enabled
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Aggregated by consumer-template into backrest's backup_plans. Jitsi state is ephemeral (videobridge has no persistent data); opt_dir captures prosody/jicofo/jvb config bind-mounts under `/opt/jitsi/*` which is the only host-side state worth snapshotting."
  value = (var.enabled && var.backup_enabled) ? {
    id               = local.slug
    paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept populated for belt-and-suspenders backward compat
    opt_dir          = true
    volumes          = []
    excluded_volumes = []
    extra_paths      = var.backup_extra_paths
    pre_hooks        = []
    post_hooks       = []
    excludes         = []
    schedule         = { cron = var.backup_schedule_cron }
    retention        = var.backup_retention
  } : null
}
