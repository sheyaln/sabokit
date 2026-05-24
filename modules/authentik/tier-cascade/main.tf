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

locals {
  # tier_names = [t0, t1, t2, t3] ordered low→high.
  # Pair each tier with its parent (the tier immediately below). The root
  # (lowest) tier has no parent.
  tier_pairs = [
    for i, name in var.tier_names : {
      name   = name
      parent = i == 0 ? null : var.tier_names[i - 1]
    }
  ]

  effective_admin_tier = coalesce(var.admin_tier, var.tier_names[length(var.tier_names) - 1])

  # For each tier, compute the set of tiers at-or-above it (inclusive).
  # tier_cascade["member"]    = [member, delegate, treasurer, admin]
  # tier_cascade["delegate"]  = [delegate, treasurer, admin]
  # tier_cascade["treasurer"] = [treasurer, admin]
  # tier_cascade["admin"]     = [admin]
  # Apps gating on tier T receive this list so they can either (a) bind one
  # policy per group (belt-and-suspenders) or (b) bind only T and rely on
  # nesting. Both work; the explicit list also feeds OIDC `groups`-claim
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

resource "authentik_group" "tier" {
  for_each = { for pair in local.tier_pairs : pair.name => pair }

  name         = each.value.name
  is_superuser = each.value.name == local.effective_admin_tier
  parents      = each.value.parent == null ? [] : [authentik_group.tier[each.value.parent].id]
  roles        = try(var.tier_roles[each.value.name], [])
  users = (
    each.value.name == local.effective_admin_tier && var.admin_user_pks != null
    ? var.admin_user_pks
    : try(var.tier_extra_users[each.value.name], null)
  )

  attributes = jsonencode({
    description = try(
      var.tier_attributes[each.value.name],
      "${each.value.name} tier — auto-managed by the tier-cascade module",
    )
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value.name == local.effective_admin_tier
        applicationEdit    = each.value.name == local.effective_admin_tier
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = {
        userDisplay = "username"
      }
    }
  })
}
