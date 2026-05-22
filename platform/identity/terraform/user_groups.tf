# Platform base groups.
#
# Admin and member are always created. Delegate is created when
# var.delegate_group_name is non-null (it's the elevated-but-not-admin tier,
# named "delegate"/"editor"/"moderator" depending on org convention).
#
# Any other group (e.g. service-account groups, app-integration groups) is
# created via var.extra_groups so consumers don't need to fork this module.

resource "authentik_group" "admin" {
  name         = var.admin_group_name
  is_superuser = true
  attributes = jsonencode({
    description = "Administrative users with full access"
    settings = {
      enabledFeatures = {
        apiDrawer          = true
        applicationEdit    = true
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

resource "authentik_group" "member" {
  name         = var.member_group_name
  is_superuser = false
  attributes = jsonencode({
    description = "Standard members with baseline access"
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

# Delegate group + RBAC role assignment lives in roles.tf so the role is
# defined alongside its permission set.

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
