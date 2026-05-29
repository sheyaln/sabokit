# Platform tier groups, modelled as a partial-order DAG from var.tier_slots.
#
# Each slot is a row in the org's authority hierarchy; each peer within a slot
# is an independent role at that rank (e.g. multiple L3 officers each owning
# their own scope). A peer's group nests under every peer-group in the slot
# immediately below, so Authentik's group-nesting evaluator transitively gives
# higher-slot users membership in every group below them. App access leans on
# this directly: a bundle binds explicit group names (var.authorized_groups),
# and listing a baseline group admits every higher slot via the nesting — there
# is no platform-computed tier_cascade.
#
# Within a slot, peers are NOT linked by nesting (admin and secretary-treasurer
# in the same slot do not inherit each other's membership); to admit both, the
# consumer lists both in an app's authorized_groups.
#
# The DAG is implemented as twelve per-slot resources, each `for_each` over
# the peers in that slot. The fan-out (multiple peers per slot, parents =
# all peers in the slot below) cannot collapse to a single self-referencing
# for_each without tripping Terraform's cycle detector — explicit per-slot
# addresses break that. Cap is 12 slots; raise additively if an org needs
# deeper rank hierarchies (at which point RBAC roles are probably the right
# tool, not group nesting).

locals {
  # Convenience accessors. Slots beyond the consumer's input resolve to an
  # empty map and the corresponding resource block's for_each is empty.
  slot_count = length(var.tier_slots)
  slot_0     = var.tier_slots[0].peers
  slot_1     = local.slot_count >= 2 ? var.tier_slots[1].peers : {}
  slot_2     = local.slot_count >= 3 ? var.tier_slots[2].peers : {}
  slot_3     = local.slot_count >= 4 ? var.tier_slots[3].peers : {}
  slot_4     = local.slot_count >= 5 ? var.tier_slots[4].peers : {}
  slot_5     = local.slot_count >= 6 ? var.tier_slots[5].peers : {}
  slot_6     = local.slot_count >= 7 ? var.tier_slots[6].peers : {}
  slot_7     = local.slot_count >= 8 ? var.tier_slots[7].peers : {}
  slot_8     = local.slot_count >= 9 ? var.tier_slots[8].peers : {}
  slot_9     = local.slot_count >= 10 ? var.tier_slots[9].peers : {}
  slot_10    = local.slot_count >= 11 ? var.tier_slots[10].peers : {}
  slot_11    = local.slot_count >= 12 ? var.tier_slots[11].peers : {}

  # group_name → group_id for every peer-group across every slot.
  # Flat map fed to base.authentik.groups (so existing `groups[<name>]`
  # lookups in flows.tf and consumer-template keep working).
  slot_group_ids = merge(
    { for k, g in authentik_group.slot_0 : g.name => g.id },
    { for k, g in authentik_group.slot_1 : g.name => g.id },
    { for k, g in authentik_group.slot_2 : g.name => g.id },
    { for k, g in authentik_group.slot_3 : g.name => g.id },
    { for k, g in authentik_group.slot_4 : g.name => g.id },
    { for k, g in authentik_group.slot_5 : g.name => g.id },
    { for k, g in authentik_group.slot_6 : g.name => g.id },
    { for k, g in authentik_group.slot_7 : g.name => g.id },
    { for k, g in authentik_group.slot_8 : g.name => g.id },
    { for k, g in authentik_group.slot_9 : g.name => g.id },
    { for k, g in authentik_group.slot_10 : g.name => g.id },
    { for k, g in authentik_group.slot_11 : g.name => g.id },
  )

  # All group_names declared across every slot. Used to validate the named
  # pointer vars (admin/member/delegate_group_name) actually map to a peer.
  all_group_names = flatten([for s in var.tier_slots : values(s.peers)])

  delegate_enabled = var.delegate_group_name != null && contains(local.all_group_names, var.delegate_group_name)
}

# ── Slot 0 (lowest privilege) ──────────────────────────────────────────────
# Parents empty; everything above nests downward into this slot.

resource "authentik_group" "slot_0" {
  for_each = local.slot_0

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = []
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[0].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 1 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_1" {
  for_each = local.slot_1

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_0 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[1].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 2 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_2" {
  for_each = local.slot_2

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_1 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[2].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 3 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_3" {
  for_each = local.slot_3

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_2 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[3].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 4 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_4" {
  for_each = local.slot_4

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_3 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[4].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 5 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_5" {
  for_each = local.slot_5

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_4 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[5].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 6 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_6" {
  for_each = local.slot_6

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_5 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[6].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 7 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_7" {
  for_each = local.slot_7

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_6 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[7].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 8 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_8" {
  for_each = local.slot_8

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_7 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[8].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 9 ─────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_9" {
  for_each = local.slot_9

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_8 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[9].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 10 ────────────────────────────────────────────────────────────────

resource "authentik_group" "slot_10" {
  for_each = local.slot_10

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_9 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[10].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# ── Slot 11 (highest privilege when present) ───────────────────────────────

resource "authentik_group" "slot_11" {
  for_each = local.slot_11

  name         = each.value
  is_superuser = each.value == var.admin_group_name
  parents      = [for k, g in authentik_group.slot_10 : g.id]
  roles        = each.value == var.delegate_group_name && local.delegate_enabled ? [authentik_rbac_role.delegate[0].id] : []
  users = (
    each.value == var.admin_group_name && var.admin_user_pks != null
    ? var.admin_user_pks
    : null
  )

  attributes = jsonencode({
    description = "${each.key} peer (slot ${var.tier_slots[11].name}) — auto-managed"
    settings = {
      enabledFeatures = {
        apiDrawer          = each.value == var.admin_group_name
        applicationEdit    = each.value == var.admin_group_name
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}

# Extra (non-cascade) platform groups. Service accounts, app-specific gating,
# etc. Don't participate in the tier DAG.
resource "authentik_group" "extra" {
  for_each     = var.extra_groups
  name         = each.key
  is_superuser = each.value.is_superuser
  attributes = jsonencode({
    description = each.value.description
    settings = {
      enabledFeatures = {
        apiDrawer          = false
        applicationEdit    = false
        notificationDrawer = true
        search             = true
        settings           = true
      }
      navbar = { userDisplay = "username" }
    }
  })
}
