# Platform tier groups, chained via the tier-cascade module.
#
# Each tier inherits all lower tiers via Authentik group nesting — a binding on
# `member` admits delegate/treasurer/admin too. The four-tier default
# (member → delegate → treasurer → admin) is generic but tunable: drop
# treasurer with var.treasurer_group_name = null, or rewrite the whole list
# via var.tier_names_override.
#
# The delegate tier carries the RBAC role defined in roles.tf (elevated
# user/group management without superuser). The admin tier is flagged
# is_superuser by the cascade module.
#
# Any group beyond the cascade (e.g. service-account groups, app-integration
# groups) is created via var.extra_groups so consumers don't fork this module.

locals {
  # Resolved tier list. Three knobs:
  #   1. tier_names_override = ["foo","bar",...] — full control.
  #   2. Otherwise, build from admin/member/delegate/treasurer names; null on
  #      any of delegate/treasurer drops that tier (admin + member are required).
  default_tier_names = compact([
    var.member_group_name,
    var.delegate_group_name,
    var.treasurer_group_name,
    var.admin_group_name,
  ])
  resolved_tier_names = length(var.tier_names_override) > 0 ? var.tier_names_override : local.default_tier_names

  delegate_enabled = var.delegate_group_name != null && contains(local.resolved_tier_names, var.delegate_group_name)
}

module "tier_cascade" {
  source = "../../../modules/authentik/tier-cascade"

  tier_names     = local.resolved_tier_names
  admin_tier     = var.admin_group_name
  admin_user_pks = var.admin_user_pks

  tier_attributes = {
    (var.member_group_name) = "Standard members with baseline access"
    (var.admin_group_name)  = "Administrative users with full access"
  }

  tier_roles = local.delegate_enabled ? {
    (var.delegate_group_name) = [authentik_rbac_role.delegate[0].id]
  } : {}
}

# Extra (non-cascade) platform groups. Same shape as before — service accounts,
# app-specific gating, etc. Don't participate in the tier inheritance.
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
      navbar = {
        userDisplay = "username"
      }
    }
  })
}
