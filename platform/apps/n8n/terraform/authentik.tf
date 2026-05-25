module "authentik" {
  source = "../../../../modules/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = var.application_name
  application_slug = local.slug
  category_group   = var.category_group
  icon_url         = var.icon_url
  description      = "Workflow automation"
  launch_url       = local.app_url

  redirect_uris = [{
    matching_mode = "strict"
    url           = local.oidc_callback_url
  }]

  authorized_groups = local.authorized_groups

  # `groups` carries the user's Authentik group names — the hook reads it to
  # decide owner vs member. `offline_access` keeps the session alive across
  # long-running workflow editor sessions.
  oidc_scopes = ["openid", "profile", "email", "groups", "offline_access"]
  sub_mode    = "user_email"

  access_token_validity  = "hours=1"
  refresh_token_validity = "days=30"

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow
}

# Service account + API token n8n uses for server-to-server Authentik admin
# calls (workflows that sync users, fetch groups, post to events, etc.).
# Membership in "authentik Admins" mirrors steward's shape; future iteration
# should scope down to a custom Role with read-only or user/group-only perms.
data "authentik_group" "admins" {
  count = var.enabled ? 1 : 0
  name  = "authentik Admins"
}

resource "authentik_user" "service_n8n" {
  count = var.enabled ? 1 : 0

  # Username = email per the platform "username = email always" invariant
  # (v2.15.0 established it for human users; v2.15.3 aligned service accounts).
  username  = "svc-${local.slug}@${var.base.domains.base_domain}"
  name      = "n8n service account"
  email     = "svc-${local.slug}@${var.base.domains.base_domain}"
  type      = "service_account"
  is_active = true
  path      = "service-accounts"
  groups    = [data.authentik_group.admins[0].id]
}

resource "authentik_token" "service_n8n" {
  count = var.enabled ? 1 : 0

  identifier   = "${local.slug}-api-token"
  intent       = "api"
  user         = authentik_user.service_n8n[0].id
  expiring     = false
  retrieve_key = true
  description  = "Server-to-server API token for the n8n workflow engine."
}
