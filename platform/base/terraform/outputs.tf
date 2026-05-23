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
  }
}

output "compute" {
  description = "Compute hosts apps can target via Ansible."
  value = {
    hosts = {
      for k, h in module.compute_host : k => {
        id            = h.instance_id
        name          = h.instance_name
        public_ip     = h.ip_address
        private_ip    = h.private_ip
        ansible_group  = var.compute_hosts[k].ansible_group
        ansible_groups = var.compute_hosts[k].ansible_groups
        role          = var.compute_hosts[k].role
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
  }
}

# Convenience flat outputs (most consumers prefer the structured maps above)

output "private_network_id" {
  description = "Convenience alias for scaleway.private_network_id."
  value       = module.network.id
}

output "default_security_group_id" {
  description = "Convenience alias for scaleway.default_security_group_id."
  value       = module.default_security_group.id
}
