# OIDC application (front door: end-user login redirect flow).
module "authentik" {
  source = "../../../../modules/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = "Steward"
  application_slug = local.slug
  category_group   = var.category_group
  icon_url         = var.icon_url
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
}

# Service account + API token Steward uses for server-to-server Authentik
# admin calls (creating members, assigning groups, etc.). Membership in the
# built-in "authentik Admins" group gives blanket admin perms; a future
# iteration should scope this down to user/group management only.
data "authentik_group" "admins" {
  count = var.enabled ? 1 : 0
  name  = "authentik Admins"
}

resource "authentik_user" "service_account" {
  count = var.enabled ? 1 : 0

  username  = "${local.slug}-svc"
  name      = "Steward service account"
  email     = "${local.slug}-svc@${var.base.domains.base_domain}"
  type      = "service_account"
  is_active = true
  path      = "service-accounts"
  groups    = [data.authentik_group.admins[0].id]
}

resource "authentik_token" "service_account" {
  count = var.enabled ? 1 : 0

  identifier  = "${local.slug}-api-token"
  intent      = "api"
  user        = authentik_user.service_account[0].id
  expiring    = false
  description = "Server-to-server API token for the Steward web app."
}
