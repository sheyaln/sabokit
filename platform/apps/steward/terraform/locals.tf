locals {
  slug = "steward"

  # Authorized groups = the access-level group from base + any extras.
  # Map keys are static role names so for_each can plan before identity-apply
  # has populated the actual group UUIDs.
  authorized_groups = var.enabled ? merge(
    { (var.access_level) = var.base.authentik.groups[var.access_level] },
    var.extra_authorized_groups,
  ) : {}

  oidc_callback_url = "https://${var.hostname}/oidc/callback/"
  app_url           = "https://${var.hostname}"

  # URLs Steward talks back to Authentik on. The OIDC ones are reachable from
  # both the browser and the Steward container (same hostname in prod, unlike
  # the dev compose stack). The API URL is server-to-server only.
  authentik_base       = "https://${var.base.authentik.gateway_domain}"
  oidc_auth_endpoint   = "${local.authentik_base}/application/o/authorize/"
  oidc_token_endpoint  = "${local.authentik_base}/application/o/token/"
  oidc_userinfo_endpt  = "${local.authentik_base}/application/o/userinfo/"
  oidc_jwks_endpoint   = "${local.authentik_base}/application/o/${local.slug}/jwks/"
  authentik_api_url    = local.authentik_base
}
