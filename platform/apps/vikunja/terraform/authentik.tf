module "authentik" {
  source = "../../../../modules/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = var.application_name
  application_slug = local.application_slug
  category_group   = var.category_group
  icon_url         = var.icon_url
  description      = "Task and project tracker"
  launch_url       = local.app_url

  redirect_uris = [{
    matching_mode = "strict"
    url           = local.oidc_callback_url
  }]

  authorized_groups = local.authorized_groups

  # Vikunja reads team assignments from the `vikunja_groups` claim under a
  # custom scope name (var.oidc_groups_scope_name). The standard claims cover
  # identity; the custom scope is added on top.
  oidc_scopes = ["openid", "profile", "email", var.oidc_groups_scope_name]
  sub_mode    = "user_email"

  access_token_validity  = "hours=1"
  refresh_token_validity = "days=30"

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow
}
