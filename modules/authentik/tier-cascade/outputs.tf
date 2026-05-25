output "groups" {
  description = "Flat map of tier-name → Authentik group ID. Suitable for merging into the platform's base.authentik.groups map so existing access_level lookups keep working."
  value       = local.group_ids
}

output "admin_tier" {
  description = "Name of the tier flagged as superuser. Useful for downstream code that needs to identify \"the admin group\" without hard-coding a string."
  value       = local.effective_admin_tier
}

output "tier_cascade" {
  description = "Map of tier-key → map(group-name → Authentik group ID) listing every tier at-or-above the key tier. Outer keys are the LOGICAL tier identifiers from var.tier_keys (e.g. \"member\"), not the display names — bundles' var.tier_access_level matches these stable keys regardless of how consumers rebrand tier_names. Inner map keys are the display names (the actual Authentik group names) which apps' for_each iterates to build authorized_groups."
  value = {
    for i, name in var.tier_names : local.effective_tier_keys[i] => {
      for m in local.cascade_groups[name] : m => local.group_ids[m]
    }
  }
}
