# Native OIDC. The Wazuh dashboard delegates SSO to the opensearch-security
# plugin, which speaks OIDC when its config.yml authc block is set to type
# `openid`. This is the "batteries included" shape: users hit the dashboard
# and get redirected to Authentik directly — no forward-auth gateway
# involvement, dashboard knows who's logged in.

module "authentik" {
  source = "../../../_shared/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = var.application_name
  application_slug = local.application_slug
  category_group   = var.category_group
  icon_url         = local.effective_icon_url
  description      = "SIEM + endpoint detection"
  launch_url       = local.app_url

  redirect_uris = [{
    matching_mode = "strict"
    url           = local.oidc_callback_url
  }]

  authorized_groups = local.authorized_groups

  oidc_scopes = ["openid", "profile", "email", "groups", "offline_access"]
  sub_mode    = "user_email"

  access_token_validity  = "hours=1"
  refresh_token_validity = "days=30"

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow

}
