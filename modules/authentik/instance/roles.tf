# RBAC Roles
# Roles define sets of permissions that can be assigned to groups

# Union Delegate Role
# Allows delegates to manage users (activate/deactivate, password/MFA reset),
# assign users to groups, and manage group membership
# without access to brand or application/provider configuration
resource "authentik_rbac_role" "union_delegate" {
  name = "union-delegate"
}

# Look up permissions needed for the union-delegate role
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

# Assign permissions to the union-delegate role
# Permission format: app_label.codename

# Admin interface access
resource "authentik_rbac_permission_role" "delegate_access_admin" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.access_admin_interface.app}.${data.authentik_rbac_permission.access_admin_interface.codename}"
}

# User management permissions
resource "authentik_rbac_permission_role" "delegate_view_user" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.view_user.app}.${data.authentik_rbac_permission.view_user.codename}"
}

resource "authentik_rbac_permission_role" "delegate_change_user" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.change_user.app}.${data.authentik_rbac_permission.change_user.codename}"
}

resource "authentik_rbac_permission_role" "delegate_reset_password" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.reset_user_password.app}.${data.authentik_rbac_permission.reset_user_password.codename}"
}

resource "authentik_rbac_permission_role" "delegate_add_user" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.add_user.app}.${data.authentik_rbac_permission.add_user.codename}"
}

# Group management permissions
resource "authentik_rbac_permission_role" "delegate_view_group" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.view_group.app}.${data.authentik_rbac_permission.view_group.codename}"
}

resource "authentik_rbac_permission_role" "delegate_change_group" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.change_group.app}.${data.authentik_rbac_permission.change_group.codename}"
}

resource "authentik_rbac_permission_role" "delegate_add_user_to_group" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.add_user_to_group.app}.${data.authentik_rbac_permission.add_user_to_group.codename}"
}

resource "authentik_rbac_permission_role" "delegate_remove_user_from_group" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.remove_user_from_group.app}.${data.authentik_rbac_permission.remove_user_from_group.codename}"
}

# Application viewing (to see assigned applications, but not edit)
resource "authentik_rbac_permission_role" "delegate_view_application" {
  role       = authentik_rbac_role.union_delegate.id
  permission = "${data.authentik_rbac_permission.view_application.app}.${data.authentik_rbac_permission.view_application.codename}"
}

# Union delegate group with role assignment
resource "authentik_group" "union_delegate" {
  name         = "union-delegate"
  is_superuser = false
  roles        = [authentik_rbac_role.union_delegate.id]

  attributes = jsonencode({
    description = "Union delegates with elevated access"
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

