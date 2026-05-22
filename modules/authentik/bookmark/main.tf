# BOOKMARK MODULE FOR AUTHENTIK
# 
# This module creates:
# 1. An Authentik Application configured as a bookmark (similar to Okta bookmarks)
# 2. No providers - just links to external URLs
# 3. Binds appropriate groups to the application for access control

locals {
  # Determine which groups should have access based on access level
  target_groups = var.access_level == "admin" ? [var.group_ids.admin] : (
    var.access_level == "delegate" ? [var.group_ids.admin, var.group_ids.union_delegate] : (
      var.access_level == "treasurer" ? [var.group_ids.admin, var.group_ids.union_delegate, var.group_ids.union_treasurer] :
      [var.group_ids.admin, var.group_ids.union_delegate, var.group_ids.union_treasurer, var.group_ids.union_member]
    )
  )
}

# Create the Bookmark Application
resource "authentik_application" "bookmark" {
  name              = var.application_name
  slug              = var.application_slug
  protocol_provider = null # No provider for bookmarks

  group = var.category_group

  meta_launch_url = var.launch_url
  # UI settings
  meta_description = var.description
  open_in_new_tab  = var.open_in_new_tab
  meta_icon        = var.icon_url != null ? var.icon_url : "default-logo.png" # Update to your organization's logo

  # Policy engine mode - ANY means user needs to match any binding
  # ALL means user needs to match all bindings
  policy_engine_mode = "any"

  lifecycle {
    ignore_changes = [
      meta_icon,
    ]
  }
}

# Bind groups to the application for access control
# This is Authentik's built-in RBAC.

# Admin group always has access
resource "authentik_policy_binding" "admin_group" {
  target = authentik_application.bookmark.uuid
  group  = var.group_ids.admin
  order  = 0
}

# Union delegate group (has access to delegate and member level apps)
resource "authentik_policy_binding" "delegate_group" {
  # Delegates get access to: delegate-level apps AND member-level apps
  count = contains(["delegate", "member"], var.access_level) ? 1 : 0

  target = authentik_application.bookmark.uuid
  group  = var.group_ids.union_delegate
  order  = 0
}

# Union treasurer group (has access to treasurer, delegate, and member level apps)
resource "authentik_policy_binding" "treasurer_group" {
  # Treasurers get access to: treasurer-level apps AND delegate-level apps AND member-level apps
  count = contains(["treasurer", "delegate", "member"], var.access_level) ? 1 : 0

  target = authentik_application.bookmark.uuid
  group  = var.group_ids.union_treasurer
  order  = 0
}

# Union member group (member access level only)
resource "authentik_policy_binding" "member_group" {
  count = var.access_level == "member" ? 1 : 0

  target = authentik_application.bookmark.uuid
  group  = var.group_ids.union_member
  order  = 0
}
