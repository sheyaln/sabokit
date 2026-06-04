# What the application layer surfaces. enabled_apps is the per-app dispatch map
# the layer's ansible consumes (terraform output -json enabled_apps). Each app's
# ansible pushes its own monitoring/backup/split-dns to the operations host at
# deploy time; there are no cross-layer aggregation outputs.

output "enabled_apps" {
  description = "Map of enabled app name -> {url, ansible_vars, ansible_group, monitoring}. backrest is a nested {instances = {host -> ...}} map. Null entries are disabled apps."
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
      monitoring    = module.steward.monitoring
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
    privacy_policy = module.privacy_policy.enabled ? {
      url           = module.privacy_policy.app_url
      ansible_vars  = module.privacy_policy.ansible.vars
      ansible_group = module.privacy_policy.ansible.host_group
      monitoring    = module.privacy_policy.monitoring
    } : null
    broadsheet = module.broadsheet.enabled ? {
      url           = module.broadsheet.app_url
      ansible_vars  = module.broadsheet.ansible.vars
      ansible_group = module.broadsheet.ansible.host_group
      monitoring    = module.broadsheet.monitoring
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
    # Per-host backrest instances, keyed by compute_host. The playbook iterates
    # the .instances map internally (one repo per host).
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
  }
}

output "outpost_id" {
  description = "ID of the embedded forward-auth outpost the application layer manages."
  value       = authentik_outpost.embedded.id
}
