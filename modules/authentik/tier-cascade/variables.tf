variable "tier_names" {
  description = "Ordered list of tier names, lowest privilege first. Each tier's members are inherited up the chain so apps gated on a lower tier admit users of every higher tier. Defaults model a typical org: baseline members, elevated delegates, treasurers with financial access, administrators on top. Override per consumer (e.g. [\"member\", \"editor\", \"moderator\", \"admin\"]) — keep order lowest→highest."
  type        = list(string)
  default     = ["member", "delegate", "treasurer", "admin"]

  validation {
    condition     = length(var.tier_names) >= 2 && length(var.tier_names) <= 4
    error_message = "tier_names must have 2-4 entries. The cascade is implemented as explicit per-slot resources (capped at 4) to avoid Terraform's for_each self-reference cycle. Consumers needing >4 tiers fork the module."
  }

  validation {
    condition     = length(distinct(var.tier_names)) == length(var.tier_names)
    error_message = "tier_names must be unique."
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
