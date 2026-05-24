# Delegate RBAC role.
#
# The delegate tier is the "elevated but not admin" role: can activate users,
# reset passwords, manage group membership, but cannot edit brand/applications.
# The role is defined here; the underlying group is created by the tier-cascade
# module in user_groups.tf and inherits this role via tier_roles. Whole stack
# is gated on var.delegate_group_name being non-null so consumers can opt out
# of the tier entirely.
#
# local.delegate_enabled (the gating boolean) is also defined in user_groups.tf
# because the cascade module needs to know whether to wire the role in; both
# files reference the same local so changing one is enough.

# Permission lookups (cheap, evaluated even when delegate is disabled).
data "authentik_rbac_permission" "access_admin_interface" {
  codename = "access_admin_interface"
}
data "authentik_rbac_permission" "view_user" {
  codename = "view_user"
}
data "authentik_rbac_permission" "change_user" {
  codename = "change_user"
}
data "authentik_rbac_permission" "reset_user_password" {
  codename = "reset_user_password"
}
data "authentik_rbac_permission" "view_group" {
  codename = "view_group"
}
data "authentik_rbac_permission" "change_group" {
  codename = "change_group"
}
data "authentik_rbac_permission" "add_user_to_group" {
  codename = "add_user_to_group"
}
data "authentik_rbac_permission" "remove_user_from_group" {
  codename = "remove_user_from_group"
}
data "authentik_rbac_permission" "view_application" {
  codename = "view_application"
}
data "authentik_rbac_permission" "add_user" {
  codename = "add_user"
}

resource "authentik_rbac_role" "delegate" {
  count = local.delegate_enabled ? 1 : 0
  name  = var.delegate_role_name
}

resource "authentik_rbac_permission_role" "delegate_access_admin" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.access_admin_interface.app}.${data.authentik_rbac_permission.access_admin_interface.codename}"
}

resource "authentik_rbac_permission_role" "delegate_view_user" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.view_user.app}.${data.authentik_rbac_permission.view_user.codename}"
}

resource "authentik_rbac_permission_role" "delegate_change_user" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.change_user.app}.${data.authentik_rbac_permission.change_user.codename}"
}

resource "authentik_rbac_permission_role" "delegate_reset_password" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.reset_user_password.app}.${data.authentik_rbac_permission.reset_user_password.codename}"
}

resource "authentik_rbac_permission_role" "delegate_add_user" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.add_user.app}.${data.authentik_rbac_permission.add_user.codename}"
}

resource "authentik_rbac_permission_role" "delegate_view_group" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.view_group.app}.${data.authentik_rbac_permission.view_group.codename}"
}

resource "authentik_rbac_permission_role" "delegate_change_group" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.change_group.app}.${data.authentik_rbac_permission.change_group.codename}"
}

resource "authentik_rbac_permission_role" "delegate_add_user_to_group" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.add_user_to_group.app}.${data.authentik_rbac_permission.add_user_to_group.codename}"
}

resource "authentik_rbac_permission_role" "delegate_remove_user_from_group" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.remove_user_from_group.app}.${data.authentik_rbac_permission.remove_user_from_group.codename}"
}

resource "authentik_rbac_permission_role" "delegate_view_application" {
  count      = local.delegate_enabled ? 1 : 0
  role       = authentik_rbac_role.delegate[0].id
  permission = "${data.authentik_rbac_permission.view_application.app}.${data.authentik_rbac_permission.view_application.codename}"
}

# Note: the delegate group itself is created by module.tier_cascade in
# user_groups.tf — the role above is attached to it via tier_roles.
