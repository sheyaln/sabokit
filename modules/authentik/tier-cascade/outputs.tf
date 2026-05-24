output "groups" {
  description = "Flat map of tier-name → Authentik group ID. Suitable for merging into the platform's base.authentik.groups map so existing access_level lookups keep working."
  value       = local.group_ids
}

output "admin_tier" {
  description = "Name of the tier flagged as superuser. Useful for downstream code that needs to identify \"the admin group\" without hard-coding a string."
  value       = local.effective_admin_tier
}

output "tier_cascade" {
  description = "Map of tier-name → map(tier-name → Authentik group ID) listing every tier at-or-above the key tier. Apps gate on tier T by binding a policy to each group in tier_cascade[T]; the per-tier nesting in Authentik also covers the cascade implicitly, so binding only T works too. The map shape matches what app bundles' authorized_groups for_each expects."
  value = {
    for tier, members in local.cascade_groups : tier => {
      for m in members : m => local.group_ids[m]
    }
  }
}
