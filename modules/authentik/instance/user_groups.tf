# Groups
resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = true
  attributes = jsonencode({
    description = "Administrative users with full access"
    settings = {
      enabledFeatures = {
        apiDrawer          = true # Admins can access API drawer
        applicationEdit    = true # Admins can edit applications
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

# Note: authentik_group.union_delegate is defined in roles.tf
# with role assignment for RBAC permissions

resource "authentik_group" "union_member" {
  name         = "union-member"
  is_superuser = false
  attributes = jsonencode({
    description = "Union members with standard access"
    settings = {
      enabledFeatures = {
        apiDrawer          = false # Members don't need API access
        applicationEdit    = false # Can't edit applications
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

resource "authentik_group" "union_treasurer" {
  name         = "union-secretary-treasurer"
  is_superuser = false
  attributes = jsonencode({
    description = "Union treasurers with financial access"
    settings = {
      enabledFeatures = {
        apiDrawer          = false # Treasurers don't need API access
        applicationEdit    = false # Can't edit applications
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


# ── Automation & Integration Groups ──────────────────────────────────────────
# Synced to downstream apps (e.g. Nextcloud) on login via the union- prefix
# convention. Assign these to service accounts or users that need app-level
# elevated access beyond standard member permissions.

resource "authentik_group" "union_automation" {
  name         = "union-automation"
  is_superuser = false
}

resource "authentik_group" "union_cloud_admin" {
  name         = "union-cloud-admin"
  is_superuser = false
}

# Enrollment allowlist - NO LONGER USED (Self-enrollment is disabled)
# resource "authentik_group" "enrollment_allowlist" {
#   name         = "enrollment-allowlist"
#   is_superuser = false
#   attributes = jsonencode({
#     description = "DEPRECATED - Self-enrollment is disabled. Delegates create accounts manually."
#     allowed_emails = []
#   })
# }
