# Forward-auth — BentoPDF doesn't speak OIDC natively; Authentik's embedded
# outpost protects every request via the Traefik middleware. The exported
# provider_id must be added to identity's `extra_forward_auth_provider_ids`
# so the outpost knows to handle this app.

module "authentik" {
  source = "../../../../modules/authentik/traefik-forward-auth"
  count  = var.enabled ? 1 : 0

  application_name = var.application_name
  application_slug = local.application_slug
  category_group   = var.category_group
  icon_url         = var.icon_url
  description      = "Browser-based PDF toolkit"
  external_host    = local.app_url
  launch_url       = local.app_url

  authorized_groups = local.authorized_groups

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow
}
