# OIDC application (front door: end-user login redirect flow).
module "authentik" {
  source = "../../../../modules/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = var.application_name
  application_slug = local.application_slug
  category_group   = var.category_group
  icon_url         = local.effective_icon_url
  description      = "Member administration"
  launch_url       = local.app_url

  redirect_uris = [{
    matching_mode = "strict"
    url           = local.oidc_callback_url
  }]

  authorized_groups = local.authorized_groups

  oidc_scopes = ["openid", "profile", "email", "groups"]
  sub_mode    = "user_email"

  access_token_validity  = "minutes=10"
  refresh_token_validity = "days=30"

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow

  credentials_preserve = var.credentials_preserve
}

# Service account + API token Steward uses for server-to-server Authentik
# admin calls (creating members, assigning groups, etc.). Membership in the
# built-in "authentik Admins" group gives blanket admin perms; a future
# iteration should scope this down to user/group management only.
data "authentik_group" "admins" {
  count = var.enabled ? 1 : 0
  name  = "authentik Admins"
}

resource "authentik_user" "service_steward" {
  count = var.enabled ? 1 : 0

  # Username = email per the platform "username = email always" invariant
  # (v2.15.0 established it for human users; v2.15.3 aligned service accounts).
  username  = "svc-${local.slug}@${var.base.domains.base_domain}"
  name      = "Steward service account"
  email     = "svc-${local.slug}@${var.base.domains.base_domain}"
  type      = "service_account"
  is_active = true
  path      = "service-accounts"
  # admin group always present; consumer-supplied extras merged in from
  # var.service_account_extra_groups — those must exist in
  # var.base.authentik.groups (created via identity's var.extra_groups).
  groups = concat(
    [data.authentik_group.admins[0].id],
    [for g in var.service_account_extra_groups : var.base.authentik.groups[g]],
  )
}

resource "authentik_token" "service_steward" {
  count = var.enabled ? 1 : 0

  identifier   = "${local.slug}-api-token"
  intent       = "api"
  user         = authentik_user.service_steward[0].id
  expiring     = false
  retrieve_key = true
  description  = "Server-to-server API token for the Steward web app."

  lifecycle {
    ignore_changes = [key]
  }
}

# State migration from the v2.15.0 names. Existing consumers' terraform state
# refers to authentik_user.service_account / authentik_token.service_account.
# `moved {}` redirects the addresses without destroy+recreate — the token
# stays valid and the username/email flip happens in-place via the in-state
# resource's attribute change.
moved {
  from = authentik_user.service_account
  to   = authentik_user.service_steward
}

moved {
  from = authentik_token.service_account
  to   = authentik_token.service_steward
}
