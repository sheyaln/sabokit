# Tier cascade — chained Authentik groups where each tier inherits all tiers
# below it. Authentik's group-nesting semantics give us this for free: when
# group B has parent A, members of B are "effective members" of A for every
# application-policy decision. Chain B→A, C→B, D→C and a binding on A admits
# anyone in B/C/D too.
#
# Direction matters: the *lowest-privilege* tier is the root parent; the
# highest-privilege tier sits at the bottom of the chain. Counter-intuitive
# until you read "child's members are also the parent's members" — admins
# need to be effective members of `member`, so admin is a descendant.
#
# The TF provider models `parents` as a list (the upstream API stores a single
# parent FK), so we always pass a one-element list.
#
# Why explicit per-tier resources instead of a single for_each:
# A for_each resource that self-references via `authentik_group.tier[parent].id`
# trips Terraform's cycle detector (graph node references itself even though
# the data dependency is acyclic by tier index). Explicit per-slot resources
# break the cycle — each one references a different resource address.
# Trade-off: tier count is capped at 4. Consumers who need >4 fork the module.
# 2-tier and 3-tier consumers work via count-gating on slots 3 + 4.

locals {
  effective_admin_tier = coalesce(var.admin_tier, var.tier_names[length(var.tier_names) - 1])

  # Convenience lookups.
  tier_count = length(var.tier_names)
  tier_0     = var.tier_names[0]
  tier_1     = local.tier_count >= 2 ? var.tier_names[1] : null
  tier_2     = local.tier_count >= 3 ? var.tier_names[2] : null
  tier_3     = local.tier_count >= 4 ? var.tier_names[3] : null

  # Map of tier-name → its resource ID. Filled per-slot below; consumers
  # access via output "groups" (flat) or output "tier_cascade" (cascade map).
  group_ids = merge(
    { (local.tier_0) = authentik_group.tier_0.id },
    local.tier_1 == null ? {} : { (local.tier_1) = authentik_group.tier_1[0].id },
    local.tier_2 == null ? {} : { (local.tier_2) = authentik_group.tier_2[0].id },
    local.tier_3 == null ? {} : { (local.tier_3) = authentik_group.tier_3[0].id },
  )

  # For each tier, the set of tiers at-or-above it (inclusive).
  # tier_cascade[tier_0] = [tier_0, tier_1, tier_2, tier_3]
  # tier_cascade[tier_1] = [tier_1, tier_2, tier_3]
  # …etc. Apps gating on tier T bind one policy per group in tier_cascade[T];
  # the per-tier nesting in Authentik also covers the cascade implicitly, so
  # binding only T works too. The explicit list also feeds OIDC `groups`-claim
  # consumers that don't resolve nesting client-side.
  tier_index = { for i, name in var.tier_names : name => i }
  cascade_groups = {
    for name in var.tier_names : name => slice(
      var.tier_names,
      local.tier_index[name],
      length(var.tier_names),
    )
  }
}

# ── Tier 0: root (lowest privilege) ────────────────────────────────────────

resource "authentik_group" "tier_0" {
  name         = local.tier_0
  is_superuser = local.tier_0 == local.effective_admin_tier
  parents      = []
  roles        = try(var.tier_roles[local.tier_0], [])
  users = (
    local.tier_0 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_0], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_0],
      "${local.tier_0} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_0 == local.effective_admin_tier
        applicationEdit    = local.tier_0 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 1 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_1" {
  count = local.tier_1 == null ? 0 : 1

  name         = local.tier_1
  is_superuser = local.tier_1 == local.effective_admin_tier
  parents      = [authentik_group.tier_0.id]
  roles        = try(var.tier_roles[local.tier_1], [])
  users = (
    local.tier_1 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_1], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_1],
      "${local.tier_1} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_1 == local.effective_admin_tier
        applicationEdit    = local.tier_1 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 2 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_2" {
  count = local.tier_2 == null ? 0 : 1

  name         = local.tier_2
  is_superuser = local.tier_2 == local.effective_admin_tier
  parents      = [authentik_group.tier_1[0].id]
  roles        = try(var.tier_roles[local.tier_2], [])
  users = (
    local.tier_2 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_2], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_2],
      "${local.tier_2} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_2 == local.effective_admin_tier
        applicationEdit    = local.tier_2 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 3 (highest privilege when present) ────────────────────────────────

resource "authentik_group" "tier_3" {
  count = local.tier_3 == null ? 0 : 1

  name         = local.tier_3
  is_superuser = local.tier_3 == local.effective_admin_tier
  parents      = [authentik_group.tier_2[0].id]
  roles        = try(var.tier_roles[local.tier_3], [])
  users = (
    local.tier_3 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_3], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_3],
      "${local.tier_3} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_3 == local.effective_admin_tier
        applicationEdit    = local.tier_3 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}
