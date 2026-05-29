# Traefik forward-auth module for Authentik.
#
# Creates an Authentik Proxy Provider in forward-auth mode, an Application,
# a per-app group, and one policy binding per entry in var.authorized_groups.
#
# The Proxy Provider works with Traefik's forwardAuth middleware to protect
# applications that don't have native OIDC/SAML support. The consumer is
# responsible for binding the resulting provider_id to an Authentik outpost
# (typically the embedded outpost provided by platform/identity/terraform/).

resource "authentik_provider_proxy" "provider" {
  name = "${var.application_name} Forward Auth Provider"

  mode          = "forward_single"
  external_host = var.external_host

  authorization_flow  = var.authorization_flow_uuid
  authentication_flow = var.authentication_flow_uuid
  invalidation_flow   = var.invalidation_flow_uuid

  access_token_validity = var.access_token_validity
  cookie_domain         = var.cookie_domain
  skip_path_regex       = var.skip_path_regex
  basic_auth_enabled    = var.basic_auth_enabled
}

resource "authentik_group" "application" {
  name         = "app-${var.application_slug}"
  is_superuser = false

  attributes = jsonencode({
    description = "Users with access to ${var.application_name} (forward auth protected)"
  })
}

resource "authentik_application" "application" {
  name              = var.application_name
  slug              = var.application_slug
  protocol_provider = authentik_provider_proxy.provider.id

  group = var.category_group

  meta_launch_url  = var.launch_url != null ? var.launch_url : var.external_host
  meta_description = var.description
  open_in_new_tab  = true
  meta_icon        = var.icon_url != "" ? var.icon_url : "default-logo.png"

  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "application_group" {
  target = authentik_application.application.uuid
  group  = authentik_group.application.id
  order  = 0
}

resource "authentik_policy_binding" "authorized" {
  for_each = var.authorized_groups

  target = authentik_application.application.uuid
  group  = each.value
  # Authentik's API enforces uniqueness on (policy, target, order) for UPDATE.
  # A hardcoded order=10 across all bindings means the 2nd binding onward
  # fails with HTTP 400 — and you can't reverse out of a partial apply
  # because the pre-check rejects both directions. Stagger via lex-ordered
  # key index so each binding lands in a distinct slot.
  order = 10 + index(keys(var.authorized_groups), each.key)
}
