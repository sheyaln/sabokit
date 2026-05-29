# tier_cascade is a pure function of the tier DAG (config) and the group-name →
# id map (discovered) — never carried across the layer boundary as an opaque
# value (impractical to read a computed Authentik map back out). This is the
# same algorithm as identity's locals.tf, lifted verbatim with slot_group_ids
# repointed at the discovered groups. If the cascade semantics ever change,
# both copies move together; that coupling is the cost of letting downstream
# layers reconstruct it without a dependency on identity's state.

locals {
  # group_name → group_id for every group the contract discovered.
  discovered_groups = { for n in local.all_group_names : n => data.authentik_group.this[n].id }

  # Per-slot-index: the group_names in every strictly-higher slot.
  groups_above_slot = {
    for i in range(length(var.tier_slots)) :
    i => flatten([
      for j in range(i + 1, length(var.tier_slots)) :
      values(var.tier_slots[j].peers)
    ])
  }

  # peer_name → map(group_name → group_id): the peer's own group plus every
  # group in every strictly-higher slot. In-slot peers do not bridge.
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
      { (entry.own_group) = local.discovered_groups[entry.own_group] },
      {
        for gn in local.groups_above_slot[entry.slot_index] :
        gn => local.discovered_groups[gn]
      },
    )
  }
}
