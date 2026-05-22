# TRAEFIK FORWARD AUTH MODULE FOR AUTHENTIK
#
# This module creates:
# 1. A Proxy Provider in forward auth (single application) mode
# 2. An Authentik Application linked to the provider
# 3. Group bindings for access control
#
# The Proxy Provider works with Traefik's forwardAuth middleware to protect
# applications that don't have native OIDC/SAML support.
#
# Usage:
#   - Create this module for each app you want to protect with forward auth
#   - Configure your Traefik router to use the authentik middleware
#   - The embedded outpost in Authentik handles authentication

locals {
  # Determine which groups should have access based on access level
  target_groups = var.access_level == "admin" ? [var.group_ids.admin] : (
    var.access_level == "delegate" ? [var.group_ids.admin, var.group_ids.union_delegate] : (
      var.access_level == "treasurer" ? [var.group_ids.admin, var.group_ids.union_delegate, var.group_ids.union_treasurer] :
      [var.group_ids.admin, var.group_ids.union_delegate, var.group_ids.union_treasurer, var.group_ids.union_member]
    )
  )
}

# Create the Proxy Provider in forward auth mode
resource "authentik_provider_proxy" "provider" {
  name = "${var.application_name} Forward Auth Provider"

  # Forward auth mode for single application
  mode = "forward_single"

  # The external host URL that this provider protects
  external_host = var.external_host

  # Authentication and authorization flows
  authorization_flow  = var.authorization_flow_uuid
  authentication_flow = var.authentication_flow_uuid
  invalidation_flow   = var.invalidation_flow_uuid

  # Token validity settings
  access_token_validity = var.access_token_validity

  # Cookie settings for forward auth
  cookie_domain = var.cookie_domain

  # Skip path regex - paths that don't require authentication
  # Common examples: health checks, static assets, webhooks
  skip_path_regex = var.skip_path_regex

  # Basic auth settings (disabled by default)
  basic_auth_enabled = var.basic_auth_enabled
}

# Create a dedicated group for this application for app-specific RBAC assignments
resource "authentik_group" "application" {
  name         = "app-${var.application_slug}"
  is_superuser = false

  attributes = jsonencode({
    description = "Users with access to ${var.application_name} (forward auth protected)"
  })
}

# Create the Application
resource "authentik_application" "application" {
  name              = var.application_name
  slug              = var.application_slug
  protocol_provider = authentik_provider_proxy.provider.id

  group = var.category_group

  meta_launch_url = var.launch_url != null ? var.launch_url : var.external_host

  # UI settings
  meta_description = var.description
  open_in_new_tab  = true
  meta_icon        = var.icon_url != null ? var.icon_url : "default-logo.png" # Update to your organization's logo

  # Policy engine mode - ANY means user needs to match any binding
  policy_engine_mode = "any"

  lifecycle {
    ignore_changes = [
      # meta_icon,
    ]
  }
}

# Bind groups to the application for access control

# Admin group always has access
resource "authentik_policy_binding" "admin_group" {
  target = authentik_application.application.uuid
  group  = var.group_ids.admin
  order  = 0
}

# Application-specific group binding
resource "authentik_policy_binding" "application_group" {
  target = authentik_application.application.uuid
  group  = authentik_group.application.id
  order  = 0
}

# Union delegate group
resource "authentik_policy_binding" "delegate_group" {
  count = contains(["delegate", "member"], var.access_level) ? 1 : 0

  target = authentik_application.application.uuid
  group  = var.group_ids.union_delegate
  order  = 0
}

# Union treasurer group
resource "authentik_policy_binding" "treasurer_group" {
  count = contains(["treasurer", "delegate", "member"], var.access_level) ? 1 : 0

  target = authentik_application.application.uuid
  group  = var.group_ids.union_treasurer
  order  = 0
}

# Union member group
resource "authentik_policy_binding" "member_group" {
  count = var.access_level == "member" ? 1 : 0

  target = authentik_application.application.uuid
  group  = var.group_ids.union_member
  order  = 0
}
