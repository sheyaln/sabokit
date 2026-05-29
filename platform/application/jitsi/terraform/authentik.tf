module "authentik" {
  source = "../../../../modules/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = var.application_name
  application_slug = local.application_slug
  category_group   = var.category_group
  icon_url         = local.effective_icon_url
  description      = "Self-hosted video conferencing"
  launch_url       = local.app_url

  redirect_uris = [{
    matching_mode = "strict"
    url           = local.oidc_callback_url
  }]

  authorized_groups = local.authorized_groups

  oidc_scopes = ["openid", "profile", "email"]
  sub_mode    = "user_email"

  # Jitsi sessions are short-lived; an hour covers all but the longest meetings
  # and forces a fresh login for users who close and reopen the tab a day later.
  access_token_validity  = "hours=1"
  refresh_token_validity = "days=7"

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow

}
