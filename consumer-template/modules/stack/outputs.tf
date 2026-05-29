# What the per-env root surfaces to the consumer (and to Ansible via
# deploy.sh's `terraform output -json enabled_apps`).

output "compute_hosts" {
  description = "Compute hosts. SSH in with the keys configured in Scaleway."
  value       = module.base.compute.hosts
}

output "authentik_identity_domain" {
  description = "Where to point DNS so users can reach Authentik."
  value       = module.base.domains.identity_domain
}

output "postgres_admin_credentials_secret_id" {
  description = "Scaleway secret holding Postgres admin credentials. Operator-only emergency access; not consumed by any ansible role. Per-app DBs are provisioned by their bundle with their own least-privilege credentials."
  value       = module.base.scaleway.postgres_admin_credentials_secret_id
}

output "identity_bootstrap" {
  description = "Map of Scaleway secret IDs (plus the non-secret authentik_version pin) the Ansible bootstrap.yml feeds to the authentik-server role. Passed verbatim as -e identity_bootstrap=$(terraform output -json identity_bootstrap)."
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

output "spf_include" {
  description = "TEM SPF include directive (e.g. include:_spf.tem.scaleway.com). Compose into a single SPF TXT record via custom_dns_records alongside any other sender includes (protonmail, sendgrid, etc.)."
  value       = module.base.spf_include
}

output "monitoring_loki_push_url" {
  description = "Push URL the bootstrap monitoring-agent role wires into Alloy. Empty when loki isn't deployed in-cluster; consumers shipping logs to an external Loki should override via extra ansible vars."
  value       = module.core.loki.enabled ? module.core.loki.push_url : ""
}

output "split_dns_overrides" {
  description = "Map of public-hostname -> private-VPC-IP overrides aggregated from every enabled bundle's split_dns_entries. Consumed by the base split-dns ansible role on every host. Empty map when only one compute host exists (single-host topologies need no split-horizon)."
  value       = local.split_dns_overrides
}

locals {
  # Host-services from the base layer: one entry per (service, host) pair the
  # base for_each instantiated. Flatten into enabled_apps keyed
  # `<service>_<host>` so the existing apps.yml playbook-import dispatch
  # picks them up without a separate code path.
  host_services_enabled_apps = merge([
    for svc, instances in module.base.host_services : {
      for host_key, inst in instances : "${svc}_${host_key}" => {
        ansible_vars  = inst.ansible_vars
        ansible_group = inst.ansible_group
      } if inst != null && try(inst.enabled, true)
    }
  ]...)
}

output "enabled_apps" {
  description = "Map of enabled app name -> bundle outputs. Consumed by Ansible via `terraform output -json enabled_apps`. Includes per-host host-services entries keyed `<service>_<host>` (e.g. `autoheal_tools`, `wazuh_agent_management`), plus the core-tier services (loki/prometheus/grafana/wazuh) merged through module.core.core_apps."
  value = merge(local.host_services_enabled_apps, module.core.core_apps, {
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
    broadsheet = module.broadsheet.enabled ? {
      url           = module.broadsheet.app_url
      ansible_vars  = module.broadsheet.ansible.vars
      ansible_group = module.broadsheet.ansible.host_group
      monitoring    = module.broadsheet.monitoring
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
    # Per-host backrest instances. One entry per compute_hosts key not in
    # var.apps.backrest.disabled_hosts. apps.yml consumes the .instances map
    # directly; the playbook iterates internally over instances matching each
    # host's group_names.
    backrest = length(module.backrest) > 0 ? {
      instances = {
        for k, inst in module.backrest : k => {
          url           = inst.app_url
          ansible_vars  = inst.ansible.vars
          ansible_group = inst.ansible.host_group
          monitoring    = inst.monitoring
        }
      }
    } : null
    protonmail_bridge = module.protonmail_bridge.enabled ? {
      ansible_vars  = module.protonmail_bridge.ansible.vars
      ansible_group = module.protonmail_bridge.ansible.host_group
    } : null
  })
}

output "enabled_host_services" {
  description = "Per-service per-host instance maps for the host-services sub-tier. Each service key holds a map keyed by compute_host name; entries are null on disabled hosts. Consumed by Ansible via `terraform output -json enabled_host_services` to drive host-services.yml."
  value = {
    diun = {
      for k, v in module.base.host_services.diun :
      k => v if v != null && v.enabled
    }
  }
}
