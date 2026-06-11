# The single output every downstream layer feeds to its bundles as
# `base = module.base.base`. The shape — `{ scaleway, compute, domains,
# authentik }` — is exactly what every bundle reads as var.base. The authentik
# sub-map carries only the fields bundles use (groups, icon_base_url,
# identity_domain, three flows); bundles bind an explicit authorized_groups name
# list resolved against `groups`, so there is no tier_cascade — the access
# cascade (if any) is a consumer decision. The other authentik fields (api_url,
# sources, outpost_id, branding paths, the unused flows) aren't reconstructed.

output "base" {
  description = "The base contract object. Pass verbatim as `base` to every bundle in the layer. See ARCHITECTURE.md for the field contract."
  value = {
    scaleway = {
      project_id             = var.scaleway_project_id
      region                 = var.scaleway_region
      zone                   = var.scaleway_zone
      private_network_id     = data.scaleway_vpc_private_network.this.id
      private_network_subnet = var.private_network_subnet

      security_group_ids = { for r, sg in data.scaleway_instance_security_group.role : r => sg.id }

      postgres_instance_id = var.postgres_enabled ? data.scaleway_rdb_instance.this[0].id : null
      postgres_endpoint = var.postgres_enabled ? {
        ip          = data.scaleway_rdb_instance.this[0].private_network[0].ip
        port        = tonumber(data.scaleway_rdb_instance.this[0].private_network[0].port)
        endpoint_id = data.scaleway_rdb_instance.this[0].private_network[0].endpoint_id
      } : null
      postgres_admin_user                  = var.postgres_enabled ? "${var.org_slug}-admin" : null
      postgres_admin_credentials_secret_id = var.postgres_enabled ? data.scaleway_secret.postgres_admin[0].id : null
      postgres_engine                      = var.postgres_engine

      object_storage_endpoint = "https://s3.${var.scaleway_region}.scw.cloud"
      secrets_namespace       = local.name_suffix

      smtp_config_secret_id = var.smtp_secret_name != "" ? data.scaleway_secret.smtp_config[0].id : null
      # from_email lives in the smtp bag; unused by any bundle, so left null
      # rather than spending a secret-version read. Populate if one ever needs it.
      smtp_from_email = null
    }

    compute = {
      hosts = {
        for k, h in var.compute_hosts : k => {
          id   = data.scaleway_instance_server.host[k].id
          name = data.scaleway_instance_server.host[k].name
          # The data source exposes public_ips/private_ips (plural lists of
          # {address,...}), not singular *_ip — filter each for the IPv4 entry.
          public_ip = try(
            [for ip in data.scaleway_instance_server.host[k].public_ips : ip.address if can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", ip.address))][0],
            null
          )
          private_ip = try(
            [for ip in data.scaleway_instance_server.host[k].private_ips : ip.address if can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", ip.address))][0],
            null
          )
          ansible_group  = h.ansible_group
          ansible_groups = h.ansible_groups
          role           = h.role
        }
      }
    }

    domains = {
      base_domain     = var.base_domain
      mgmt_domain     = local.mgmt_domain
      identity_domain = local.identity_domain
      zones           = distinct(compact([var.base_domain, local.mgmt_domain]))
    }

    authentik = {
      identity_domain = local.identity_domain
      icon_base_url   = var.icon_base_url != "" ? var.icon_base_url : "https://raw.githubusercontent.com/sheyaln/sabokit-assets/master/application-icons"
      groups          = local.discovered_groups
      flows = {
        authentication_flow = data.authentik_flow.authentication.id
        authorization_flow  = data.authentik_flow.authorization.id
        invalidation_flow   = data.authentik_flow.invalidation.id
      }
    }
  }
}
