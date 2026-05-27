# The base contract. Apps consume var.base which receives these outputs.
# See ARCHITECTURE.md for the full contract.
#
# Each top-level output reads from a local of the same shape. Future
# host-services modules under platform/base/host-services/ pull these same
# locals via a self-reference rather than re-deriving the data.

locals {
  scaleway_output = {
    project_id             = var.scaleway_project_id
    region                 = var.scaleway_region
    zone                   = var.scaleway_zone
    private_network_id     = module.network.id
    private_network_subnet = var.private_network_subnet

    default_security_group_id = module.default_security_group.id

    postgres_instance_id                 = var.postgres_enabled ? module.postgres[0].instance_id : null
    postgres_endpoint                    = var.postgres_enabled ? module.postgres[0].endpoint : null
    postgres_admin_user                  = var.postgres_enabled ? module.postgres[0].admin_user : null
    postgres_admin_credentials_secret_id = var.postgres_enabled ? module.postgres[0].admin_credentials_secret_id : null
    postgres_engine                      = var.postgres_engine

    object_storage_endpoint = "https://s3.${var.scaleway_region}.scw.cloud"
    secrets_namespace       = local.name_suffix

    # Scaleway TEM outbound SMTP. Apps reference the smtp-config secret
    # by name; these outputs are for diagnostics + consumer-template wiring.
    # ID resolves to the live bag whether base wrote it or `smtp_config_preserve`
    # is reading a pre-existing legacy-managed one — see tem.tf.
    smtp_config_secret_id = local.smtp_config_secret_id
    smtp_from_email       = var.tem_enabled ? local.tem_from_email_resolved : null
  }

  compute_output = {
    hosts = {
      for k, h in module.compute_host : k => {
        id             = h.instance_id
        name           = h.instance_name
        public_ip      = h.ip_address
        private_ip     = h.private_ip
        ansible_group  = var.compute_hosts[k].ansible_group
        ansible_groups = var.compute_hosts[k].ansible_groups
        role           = var.compute_hosts[k].role
      }
    }
  }

  domains_output = {
    base_domain    = var.base_domain
    mgmt_domain    = local.mgmt_domain
    gateway_domain = local.gateway_domain

    # Set of DNS zones the consumer owns. Per-app DNS modules consult this for
    # longest-suffix-match zone routing (split-domain setups). compact + distinct
    # collapse the common case where mgmt_domain defaults to base_domain.
    zones = distinct(compact([var.base_domain, local.mgmt_domain]))
  }
}

output "scaleway" {
  description = "Scaleway platform handles. Apps use these to provision their own resources."
  value       = local.scaleway_output
}

output "compute" {
  description = "Compute hosts apps can target via Ansible."
  value       = local.compute_output
}

output "domains" {
  description = "Domain configuration. Apps reference these via base.domains."
  value       = local.domains_output
}

# Convenience flat outputs (most consumers prefer the structured maps above)

output "spf_include" {
  description = "TEM SPF include directive (e.g. include:_spf.tem.scaleway.com). Compose into your full SPF record via custom_dns_records; the module no longer manages an SPF record because real-world SPF needs to combine multiple sender includes (TEM + protonmail/sendgrid/etc.) which can't be done by emitting a bare TEM-only record."
  value       = var.tem_enabled ? scaleway_tem_domain.this[0].spf_config : null
}

# ── Host-services sub-tier ──────────────────────────────────────────────────
# Per-host instance maps for each host-services bundle, mirroring how apps
# expose their ansible_vars. Consumer-template surfaces these via
# `enabled_apps.<service>_<host_key>` so the generated apps.yml can loop
# over instances and dispatch one play per host.

output "host_services" {
  description = "Per-host instance maps for the host-services sub-tier. Each service key holds a map keyed by compute_host name; entries are null on disabled hosts. Consumed by consumer-template to expose per-host ansible_vars to the generated host-services playbook."
  value = {
    diun = {
      for k, _ in var.compute_hosts : k => (
        contains(keys(module.diun), k)
        ? {
          enabled       = module.diun[k].enabled
          ansible_vars  = module.diun[k].ansible.vars
          ansible_group = module.diun[k].ansible.host_group
          monitoring    = module.diun[k].monitoring
        }
        : null
      )
    }
  }
}

output "private_network_id" {
  description = "Convenience alias for scaleway.private_network_id."
  value       = module.network.id
}

output "default_security_group_id" {
  description = "Convenience alias for scaleway.default_security_group_id."
  value       = module.default_security_group.id
}
