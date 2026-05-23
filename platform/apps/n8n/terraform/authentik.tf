module "authentik" {
  source = "../../../../modules/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = "Workflows (n8n)"
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
