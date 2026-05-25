# What the per-env root surfaces to the consumer (and to Ansible via
# deploy.sh's `terraform output -json enabled_apps`).

output "compute_hosts" {
  description = "Compute hosts. SSH in with the keys configured in Scaleway."
  value       = module.base.compute.hosts
}

output "authentik_gateway_domain" {
  description = "Where to point DNS so users can reach Authentik."
  value       = module.base.domains.gateway_domain
}

output "postgres_admin_credentials_secret_id" {
  description = "Scaleway secret holding Postgres admin credentials. App bundles use this for emergency access; routine per-app DBs are owned by the app bundles."
  value       = module.base.scaleway.postgres_admin_credentials_secret_id
}

output "identity_bootstrap" {
  description = "Map of Scaleway secret IDs the Ansible bootstrap.yml feeds to the authentik-server role. Passed verbatim as -e identity_bootstrap=$(terraform output -json identity_bootstrap)."
  value       = module.identity_bootstrap.identity_bootstrap
}

output "authentik_admin_secret_id" {
  description = "Scaleway secret holding the Authentik bootstrap admin credentials JSON {username, email, password, api_token}. deploy.sh fetches api_token from here for TF_VAR_authentik_admin_token."
  value       = module.identity_bootstrap.admin_secret_id
}

output "infra_email" {
  description = "Operations contact email. Surfaced so deploy.sh can pass it through to Ansible's traefik role for the Let's Encrypt ACME registration email."
  value       = var.infra_email
}

output "split_dns_overrides" {
  description = "Map of public-hostname -> private-VPC-IP overrides aggregated from every enabled bundle's split_dns_entries. Consumed by the base split-dns ansible role on every host. Empty map when only one compute host exists (single-host topologies need no split-horizon)."
  value       = local.split_dns_overrides
}

output "enabled_apps" {
  description = "Map of enabled app name -> bundle outputs. Consumed by Ansible via `terraform output -json enabled_apps`."
  value = {
    outline = module.outline.enabled ? {
      url           = module.outline.app_url
      ansible_vars  = module.outline.ansible.vars
      ansible_group = module.outline.ansible.host_group
      monitoring    = module.outline.monitoring
    } : null
    steward = module.steward.enabled ? {
      url           = module.steward.app_url
      ansible_vars  = module.steward.ansible.vars
      ansible_group = module.steward.ansible.host_group
    } : null
    vikunja = module.vikunja.enabled ? {
      url           = module.vikunja.app_url
      ansible_vars  = module.vikunja.ansible.vars
      ansible_group = module.vikunja.ansible.host_group
      monitoring    = module.vikunja.monitoring
    } : null
    bentopdf = module.bentopdf.enabled ? {
      url           = module.bentopdf.app_url
      ansible_vars  = module.bentopdf.ansible.vars
      ansible_group = module.bentopdf.ansible.host_group
      monitoring    = module.bentopdf.monitoring
    } : null
    notifuse = module.notifuse.enabled ? {
      url           = module.notifuse.app_url
      ansible_vars  = module.notifuse.ansible.vars
      ansible_group = module.notifuse.ansible.host_group
      monitoring    = module.notifuse.monitoring
    } : null
    privacy_policy = module.privacy_policy.enabled ? {
      url           = module.privacy_policy.app_url
      ansible_vars  = module.privacy_policy.ansible.vars
      ansible_group = module.privacy_policy.ansible.host_group
      monitoring    = module.privacy_policy.monitoring
    } : null
    nextcloud = module.nextcloud.enabled ? {
      url           = module.nextcloud.app_url
      ansible_vars  = module.nextcloud.ansible.vars
      ansible_group = module.nextcloud.ansible.host_group
      monitoring    = module.nextcloud.monitoring
    } : null
    decidim = module.decidim.enabled ? {
      url           = module.decidim.app_url
      ansible_vars  = module.decidim.ansible.vars
      ansible_group = module.decidim.ansible.host_group
      monitoring    = module.decidim.monitoring
    } : null
    jitsi = module.jitsi.enabled ? {
      url           = module.jitsi.app_url
      ansible_vars  = module.jitsi.ansible.vars
      ansible_group = module.jitsi.ansible.host_group
      monitoring    = module.jitsi.monitoring
    } : null
    espocrm = module.espocrm.enabled ? {
      url           = module.espocrm.app_url
      ansible_vars  = module.espocrm.ansible.vars
      ansible_group = module.espocrm.ansible.host_group
      monitoring    = module.espocrm.monitoring
    } : null
    n8n = module.n8n.enabled ? {
      url           = module.n8n.app_url
      ansible_vars  = module.n8n.ansible.vars
      ansible_group = module.n8n.ansible.host_group
      monitoring    = module.n8n.monitoring
    } : null
    prometheus = module.prometheus.enabled ? {
      ansible_vars  = module.prometheus.ansible.vars
      ansible_group = module.prometheus.ansible.host_group
      monitoring    = module.prometheus.monitoring
    } : null
    loki = module.loki.enabled ? {
      ansible_vars  = module.loki.ansible.vars
      ansible_group = module.loki.ansible.host_group
    } : null
    grafana = module.grafana.enabled ? {
      url           = module.grafana.app_url
      ansible_vars  = module.grafana.ansible.vars
      ansible_group = module.grafana.ansible.host_group
      monitoring    = module.grafana.monitoring
    } : null
    wazuh = module.wazuh.enabled ? {
      url           = module.wazuh.app_url
      ansible_vars  = module.wazuh.ansible.vars
      ansible_group = module.wazuh.ansible.host_group
      monitoring    = module.wazuh.monitoring
    } : null
    backrest_mgmt = module.backrest_mgmt.enabled ? {
      url           = module.backrest_mgmt.app_url
      ansible_vars  = module.backrest_mgmt.ansible.vars
      ansible_group = module.backrest_mgmt.ansible.host_group
      monitoring    = module.backrest_mgmt.monitoring
    } : null
    watchtower_apps = module.watchtower_apps.enabled ? {
      ansible_vars  = module.watchtower_apps.ansible.vars
      ansible_group = module.watchtower_apps.ansible.host_group
    } : null
    diun_mgmt = module.diun_mgmt.enabled ? {
      ansible_vars  = module.diun_mgmt.ansible.vars
      ansible_group = module.diun_mgmt.ansible.host_group
      monitoring    = module.diun_mgmt.monitoring
    } : null
    wazuh_agent_apps = module.wazuh_agent_apps.enabled ? {
      ansible_vars  = module.wazuh_agent_apps.ansible.vars
      ansible_group = module.wazuh_agent_apps.ansible.host_group
    } : null
    autoheal_apps = module.autoheal_apps.enabled ? {
      ansible_vars  = module.autoheal_apps.ansible.vars
      ansible_group = module.autoheal_apps.ansible.host_group
    } : null
  }
}
