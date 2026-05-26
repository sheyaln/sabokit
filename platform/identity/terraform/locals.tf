locals {
  # Resolved SMTP From display name. When the consumer doesn't set from_name
  # explicitly we fall back to the org's display name.
  from_name = var.from_name != "" ? var.from_name : var.org_name

  # JSON-encoded list of group names that should receive user-lifecycle email
  # notifications. Always includes admin; includes delegate when that tier is
  # enabled. The expressions Python templates parse this as a Python literal.
  notification_target_groups_json = jsonencode(
    var.delegate_group_name != null
    ? [var.admin_group_name, var.delegate_group_name]
    : [var.admin_group_name]
  )

  # Test mode collapses recipients to admins only.
  notification_test_target_groups_json = jsonencode([var.admin_group_name])

  # Empty icon_base_url resolves to the sabokit-assets master default so
  # consumers can pass `try(var.identity.icon_base_url, "")` straight through
  # without hardcoding the upstream URL on every fork. Tracks master rather
  # than a tag because sabokit-assets has no release cadence yet.
  effective_icon_base_url = var.icon_base_url != "" ? var.icon_base_url : "https://raw.githubusercontent.com/sheyaln/sabokit-assets/master/application-icons"

  # Pre-computed per-slot-index: list of group_names in every strictly-higher
  # slot. Used both by user_groups.tf (peer's parent linkage is the slot below)
  # and by tier_cascade below (peer's cascade is own group + groups above).
  groups_above_slot = {
    for i in range(length(var.tier_slots)) :
    i => flatten([
      for j in range(i + 1, length(var.tier_slots)) :
      values(var.tier_slots[j].peers)
    ])
  }

  # Every (slot_idx, peer_name, group_name) tuple, flattened. Drives the
  # tier_cascade output below — each peer becomes one outer key whose value
  # is a map(group_name → group_id) containing the peer's own group plus
  # every group in every strictly-higher slot. In-slot peers do NOT bridge:
  # an app scoped to peer admin in the top slot binds {admin} only, not
  # {admin, secretary-treasurer}, even when both share that slot.
  tier_cascade = {
    for entry in flatten([
      for slot_idx, slot in var.tier_slots : [
        for peer_name, group_name in slot.peers : {
          peer       = peer_name
          own_group  = group_name
          slot_index = slot_idx
        }
      ]
    ]) :
    entry.peer => merge(
      { (entry.own_group) = local.slot_group_ids[entry.own_group] },
      {
        for gn in local.groups_above_slot[entry.slot_index] :
        gn => local.slot_group_ids[gn]
      },
    )
  }
}
