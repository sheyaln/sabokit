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
# Cap is 12 (10 reasonable tiers + 2 extras for one-offs). Slots above the
# consumer's tier_count are count-gated to 0. Raising the cap later is
# additive-only — adding slot N+1 doesn't touch existing state.

locals {
  effective_admin_tier = coalesce(var.admin_tier, var.tier_names[length(var.tier_names) - 1])

  # Convenience lookups. Each slot above tier_count resolves to null and the
  # corresponding resource block's count = 0.
  tier_count = length(var.tier_names)
  tier_0     = var.tier_names[0]
  tier_1     = local.tier_count >= 2 ? var.tier_names[1] : null
  tier_2     = local.tier_count >= 3 ? var.tier_names[2] : null
  tier_3     = local.tier_count >= 4 ? var.tier_names[3] : null
  tier_4     = local.tier_count >= 5 ? var.tier_names[4] : null
  tier_5     = local.tier_count >= 6 ? var.tier_names[5] : null
  tier_6     = local.tier_count >= 7 ? var.tier_names[6] : null
  tier_7     = local.tier_count >= 8 ? var.tier_names[7] : null
  tier_8     = local.tier_count >= 9 ? var.tier_names[8] : null
  tier_9     = local.tier_count >= 10 ? var.tier_names[9] : null
  tier_10    = local.tier_count >= 11 ? var.tier_names[10] : null
  tier_11    = local.tier_count >= 12 ? var.tier_names[11] : null

  # Map of tier-name → its resource ID. Filled per-slot below; consumers
  # access via output "groups" (flat) or output "tier_cascade" (cascade map).
  group_ids = merge(
    { (local.tier_0) = authentik_group.tier_0.id },
    local.tier_1 == null ? {} : { (local.tier_1) = authentik_group.tier_1[0].id },
    local.tier_2 == null ? {} : { (local.tier_2) = authentik_group.tier_2[0].id },
    local.tier_3 == null ? {} : { (local.tier_3) = authentik_group.tier_3[0].id },
    local.tier_4 == null ? {} : { (local.tier_4) = authentik_group.tier_4[0].id },
    local.tier_5 == null ? {} : { (local.tier_5) = authentik_group.tier_5[0].id },
    local.tier_6 == null ? {} : { (local.tier_6) = authentik_group.tier_6[0].id },
    local.tier_7 == null ? {} : { (local.tier_7) = authentik_group.tier_7[0].id },
    local.tier_8 == null ? {} : { (local.tier_8) = authentik_group.tier_8[0].id },
    local.tier_9 == null ? {} : { (local.tier_9) = authentik_group.tier_9[0].id },
    local.tier_10 == null ? {} : { (local.tier_10) = authentik_group.tier_10[0].id },
    local.tier_11 == null ? {} : { (local.tier_11) = authentik_group.tier_11[0].id },
  )

  # For each tier, the set of tiers at-or-above it (inclusive).
  # tier_cascade[tier_0] = [tier_0, tier_1, ..., tier_N]
  # tier_cascade[tier_1] = [tier_1, tier_2, ..., tier_N]
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

# ── Tier 3 ─────────────────────────────────────────────────────────────────

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

# ── Tier 4 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_4" {
  count = local.tier_4 == null ? 0 : 1

  name         = local.tier_4
  is_superuser = local.tier_4 == local.effective_admin_tier
  parents      = [authentik_group.tier_3[0].id]
  roles        = try(var.tier_roles[local.tier_4], [])
  users = (
    local.tier_4 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_4], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_4],
      "${local.tier_4} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_4 == local.effective_admin_tier
        applicationEdit    = local.tier_4 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 5 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_5" {
  count = local.tier_5 == null ? 0 : 1

  name         = local.tier_5
  is_superuser = local.tier_5 == local.effective_admin_tier
  parents      = [authentik_group.tier_4[0].id]
  roles        = try(var.tier_roles[local.tier_5], [])
  users = (
    local.tier_5 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_5], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_5],
      "${local.tier_5} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_5 == local.effective_admin_tier
        applicationEdit    = local.tier_5 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 6 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_6" {
  count = local.tier_6 == null ? 0 : 1

  name         = local.tier_6
  is_superuser = local.tier_6 == local.effective_admin_tier
  parents      = [authentik_group.tier_5[0].id]
  roles        = try(var.tier_roles[local.tier_6], [])
  users = (
    local.tier_6 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_6], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_6],
      "${local.tier_6} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_6 == local.effective_admin_tier
        applicationEdit    = local.tier_6 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 7 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_7" {
  count = local.tier_7 == null ? 0 : 1

  name         = local.tier_7
  is_superuser = local.tier_7 == local.effective_admin_tier
  parents      = [authentik_group.tier_6[0].id]
  roles        = try(var.tier_roles[local.tier_7], [])
  users = (
    local.tier_7 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_7], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_7],
      "${local.tier_7} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_7 == local.effective_admin_tier
        applicationEdit    = local.tier_7 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 8 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_8" {
  count = local.tier_8 == null ? 0 : 1

  name         = local.tier_8
  is_superuser = local.tier_8 == local.effective_admin_tier
  parents      = [authentik_group.tier_7[0].id]
  roles        = try(var.tier_roles[local.tier_8], [])
  users = (
    local.tier_8 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_8], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_8],
      "${local.tier_8} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_8 == local.effective_admin_tier
        applicationEdit    = local.tier_8 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 9 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_9" {
  count = local.tier_9 == null ? 0 : 1

  name         = local.tier_9
  is_superuser = local.tier_9 == local.effective_admin_tier
  parents      = [authentik_group.tier_8[0].id]
  roles        = try(var.tier_roles[local.tier_9], [])
  users = (
    local.tier_9 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_9], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_9],
      "${local.tier_9} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_9 == local.effective_admin_tier
        applicationEdit    = local.tier_9 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 10 ────────────────────────────────────────────────────────────────

resource "authentik_group" "tier_10" {
  count = local.tier_10 == null ? 0 : 1

  name         = local.tier_10
  is_superuser = local.tier_10 == local.effective_admin_tier
  parents      = [authentik_group.tier_9[0].id]
  roles        = try(var.tier_roles[local.tier_10], [])
  users = (
    local.tier_10 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_10], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_10],
      "${local.tier_10} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_10 == local.effective_admin_tier
        applicationEdit    = local.tier_10 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Tier 11 (highest privilege when present) ───────────────────────────────

resource "authentik_group" "tier_11" {
  count = local.tier_11 == null ? 0 : 1

  name         = local.tier_11
  is_superuser = local.tier_11 == local.effective_admin_tier
  parents      = [authentik_group.tier_10[0].id]
  roles        = try(var.tier_roles[local.tier_11], [])
  users = (
    local.tier_11 == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[local.tier_11], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[local.tier_11],
      "${local.tier_11} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = local.tier_11 == local.effective_admin_tier
        applicationEdit    = local.tier_11 == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}
