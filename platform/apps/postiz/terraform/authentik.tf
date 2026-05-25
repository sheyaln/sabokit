module "authentik" {
  source = "../../../../modules/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = "Social (Postiz)"
  application_slug = local.slug
  category_group   = var.category_group
  icon_url         = var.icon_url
  description      = "Social media scheduling + content management"
  launch_url       = local.app_url

  # Postiz speaks generic OIDC via its NEXT_PUBLIC_POSTIZ_OAUTH_* env vars.
  # NOT forward-auth: Postiz has its own login UI that consumes the OIDC
  # tokens directly. Don't add this app's provider_id to identity's
  # extra_forward_auth_provider_ids list.
  redirect_uris = [{
    matching_mode = "strict"
    url           = local.oidc_callback_url
  }]

  authorized_groups = local.authorized_groups

  oidc_scopes = ["openid", "profile", "email"]
  sub_mode    = "user_email"

  access_token_validity  = "hours=1"
  refresh_token_validity = "days=30"

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow
}
