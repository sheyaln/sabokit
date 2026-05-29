# `_shared/contract` — the data-source base contract

Rebuilds the `base` object (`{ scaleway, compute, domains, authentik }`) that
bundles consume as `var.base`, by **discovering** what the infra and identity
layers provisioned — by name/tag, never `remote_state`.

In v0.1.0 the single-root stack built `local.base` in memory and handed it to
every bundle. v1.0 splits the stack into four per-env layer roots with four
separate states. The downstream layers (operations, application) can't read the
infra/identity roots' in-memory wiring, so each calls this module instead:

```hcl
module "base" {
  source = "../../_shared/contract"

  org_slug    = var.org_slug
  environment = var.environment

  scaleway_project_id = var.scaleway_project_id
  scaleway_region     = var.scaleway_region
  scaleway_zone       = var.scaleway_zone

  private_network_subnet = var.private_network_subnet
  postgres_enabled       = var.postgres_enabled
  postgres_engine        = var.postgres_engine

  base_domain     = var.base_domain
  mgmt_domain     = var.mgmt_domain
  identity_domain = var.identity_domain

  tier_slots        = var.tier_slots
  extra_group_names = keys(var.extra_groups)

  # Project the full consumer compute_hosts down to the role/ansible subset.
  compute_hosts = {
    for k, h in var.compute_hosts : k => {
      role           = h.role
      ansible_group  = h.ansible_group
      ansible_groups = h.ansible_groups
    }
  }
}

# then, per bundle:
module "outline" {
  source = "../outline/terraform"
  base   = module.base.base
  # ...
}
```

The default (unaliased) `scaleway` and `authentik` providers are inherited from
the calling root — no `providers = {}` block needed (no `scaleway.dns` alias,
since nothing here touches DNS). The root must configure the `authentik`
provider before this module's `data.authentik_*` lookups can resolve; the admin
token comes from the infra-minted `${org}-${env}-authentik-admin` secret, read
at the root.

## What's discovered vs. config-known

| field | source |
|---|---|
| `scaleway.private_network_id` | `data.scaleway_vpc_private_network` by name `${org}-${env}-network` |
| `scaleway.security_group_ids` | `data.scaleway_instance_security_group` per role, `${org}-${env}-<role>` |
| `scaleway.postgres_*` | `data.scaleway_rdb_instance` `${org}-${env}-postgres` (+ admin-credentials secret) |
| `scaleway.smtp_config_secret_id` | `data.scaleway_secret` by name (`smtp-config`) |
| `compute.hosts[*].{id,public_ip,private_ip}` | `data.scaleway_instance_server` per host, `${org}-${env}-<key>` |
| `authentik.groups`, `authentik.tier_cascade` | `data.authentik_group` per name + the lifted cascade recompute |
| `authentik.flows.*` | `data.authentik_flow` by slug |
| everything else (project/region/zone, subnet, engine, domains, roles, ansible groups, icon URL) | the layer's own variables (consumer config) |

## Trimmed `authentik` surface

`base.authentik` here carries only the fields bundles read:
`identity_domain`, `icon_base_url`, `groups`, `tier_cascade`, and
`flows.{authentication,authorization,invalidation}`. Identity's full output also
exposes `api_url`, `api_token_secret_id`, `org_name`, `sources`, `outpost_id`,
`branding_assets_path`, and five more flows — none consumed by an
operations/application bundle, so none reconstructed. A new bundle that needs
one adds the discovery here.

## tier_cascade

Not preserved across the boundary — recomputed in `cascade.tf` from `tier_slots`
(config) + the discovered groups, using the same algorithm as identity's
`locals.tf`. The two copies are coupled: change the cascade semantics in one,
change the other.
