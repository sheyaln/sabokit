output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where the privacy policy is reachable. null when disabled."
  value       = var.enabled ? local.app_url : null
}

# Privacy-policy is public — no Authentik provider or per-app group.

output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
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
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/role"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      privacy_policy_hostname              = var.hostname
      privacy_policy_page_title            = var.page_title
      privacy_policy_diun_watch_enabled    = var.diun_watch_enabled
      privacy_policy_autoheal_enabled      = var.autoheal_enabled
      privacy_policy_extra_docker_networks = var.extra_docker_networks
    }
  } : null
}

output "backup_plan" {
  description = "Backrest backup plan contribution. null when disabled or backup_enabled = false. Aggregated by consumer-template into backrest's backup_plans. Static site — opt_dir captures index.html + logo + compose, which is the entirety of the per-host state."
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
