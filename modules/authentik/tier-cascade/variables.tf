variable "tier_names" {
  description = "Ordered list of tier display names, lowest privilege first. These become the actual Authentik group names. Each tier's members are inherited up the chain so apps gated on a lower tier admit users of every higher tier. Defaults model a typical org: baseline members, elevated delegates, treasurers with financial access, administrators on top. Override per consumer (e.g. [\"union-member\", \"union-delegate\", \"union-secretary-treasurer\", \"admin\"]) to brand the groups — keep order lowest→highest. When you override these to non-default values, also set tier_keys so bundles' tier_access_level lookups keep working."
  type        = list(string)
  default     = ["member", "delegate", "treasurer", "admin"]

  validation {
    condition     = length(var.tier_names) >= 2 && length(var.tier_names) <= 12
    error_message = "tier_names must have 2-12 entries. The cascade is implemented as explicit per-slot resources (capped at 12: 10 reasonable tiers + 2 extras for one-offs) to avoid Terraform's for_each self-reference cycle. Consumers needing >12 tiers fork the module — at that point group nesting is probably the wrong tool, RBAC roles likely fit better."
  }

  validation {
    condition     = length(distinct(var.tier_names)) == length(var.tier_names)
    error_message = "tier_names must be unique."
  }
}

variable "tier_keys" {
  description = "Stable logical identifiers per tier, parallel to tier_names. App bundles' var.tier_access_level references these (e.g. \"member\", \"admin\") regardless of what the corresponding Authentik group is actually named. Defaults to tier_names when null — fine for consumers using default tier names. When you override tier_names to brand the display names, set tier_keys here to the logical identifiers your bundles expect (e.g. tier_keys = [\"member\", \"delegate\", \"treasurer\", \"admin\"] while tier_names = [\"union-member\", \"union-delegate\", \"union-secretary-treasurer\", \"admin\"]). Without this, tier_cascade is keyed by display names and every bundle's tier_access_level lookup breaks."
  type        = list(string)
  default     = null

  validation {
    condition     = var.tier_keys == null || length(var.tier_keys) == length(var.tier_names)
    error_message = "tier_keys length must match tier_names length (they're parallel lists)."
  }

  validation {
    condition     = var.tier_keys == null || length(distinct(var.tier_keys)) == length(var.tier_keys)
    error_message = "tier_keys must be unique."
  }
}

variable "admin_tier" {
  description = "Which tier (must be present in tier_names) is the superuser tier. Members of this tier get is_superuser = true on the underlying Authentik group. Defaults to the last entry of tier_names."
  type        = string
  default     = null
}

variable "admin_user_pks" {
  description = "Optional explicit user PKs to seed into the admin-tier group. Null means UI-managed membership (Terraform leaves the group's users list alone). Setting a list makes Terraform the source of truth — anyone added via the UI is reconciled out."
  type        = list(number)
  default     = null
}

variable "tier_attributes" {
  description = "Per-tier description shown in the Authentik UI. Map keys must be members of tier_names. Tiers not listed get a generic auto-generated description."
  type        = map(string)
  default     = {}
}

variable "tier_roles" {
  description = "Per-tier RBAC role IDs to attach. Map of tier-name → list of authentik_rbac_role IDs. Use this when a tier needs an explicit role (e.g. the delegate tier with elevated-but-not-superuser permissions). Tiers not listed get no roles."
  type        = map(list(string))
  default     = {}
}

variable "tier_extra_users" {
  description = "Per-tier explicit user PKs. Map of tier-name → list of numeric user IDs. Setting an entry makes Terraform the source of truth for that tier's membership; omitted tiers stay UI-managed. The admin tier is also seeded from admin_user_pks (kept separate for backward compatibility)."
  type        = map(list(number))
  default     = {}
}
