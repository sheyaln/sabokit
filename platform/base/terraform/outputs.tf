# The base contract. Apps consume var.base which receives these outputs.
# See ARCHITECTURE.md for the full contract.

output "scaleway" {
  description = "Scaleway platform handles. Apps use these to provision their own resources."
  value = {
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
    smtp_config_secret_id = var.tem_enabled ? scaleway_secret.smtp_config[0].id : null
    smtp_from_email       = var.tem_enabled ? local.tem_from_email_resolved : null
  }
}

output "compute" {
  description = "Compute hosts apps can target via Ansible."
  value = {
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
}

output "domains" {
  description = "Domain configuration. Apps reference these via base.domains."
  value = {
    base_domain    = var.base_domain
    mgmt_domain    = local.mgmt_domain
    gateway_domain = local.gateway_domain

    # Set of DNS zones the consumer owns. Per-app DNS modules consult this for
    # longest-suffix-match zone routing (split-domain setups). compact + distinct
    # collapse the common case where mgmt_domain defaults to base_domain.
    zones = distinct(compact([var.base_domain, local.mgmt_domain]))
  }
}

# Convenience flat outputs (most consumers prefer the structured maps above)

output "spf_include" {
  description = "TEM SPF include directive (e.g. include:_spf.tem.scaleway.com). Compose into your full SPF record via custom_dns_records; the module no longer manages an SPF record because real-world SPF needs to combine multiple sender includes (TEM + protonmail/sendgrid/etc.) which can't be done by emitting a bare TEM-only record."
  value       = var.tem_enabled ? scaleway_tem_domain.this[0].spf_config : null
}

output "private_network_id" {
  description = "Convenience alias for scaleway.private_network_id."
  value       = module.network.id
}

output "default_security_group_id" {
  description = "Convenience alias for scaleway.default_security_group_id."
  value       = module.default_security_group.id
}
