locals {
  slug             = "steward"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  # Authorized groups = the consumer's explicit group-name list, resolved to IDs
  # via base.authentik.groups. Map keys are the group names (static at plan), so
  # the leaf module's for_each plans before identity-apply fills the UUIDs.
  authorized_groups = var.enabled ? {
    for g in var.authorized_groups : g => var.base.authentik.groups[g]
  } : {}

  oidc_callback_url = "https://${var.hostname}/oidc/callback/"
  app_url           = "https://${var.hostname}"

  # URLs Steward talks back to Authentik on. The OIDC ones are reachable from
  # both the browser and the Steward container (same hostname in prod, unlike
  # the dev compose stack). The API URL is server-to-server only.
  authentik_base      = "https://${var.base.authentik.identity_domain}"
  oidc_auth_endpoint  = "${local.authentik_base}/application/o/authorize/"
  oidc_token_endpoint = "${local.authentik_base}/application/o/token/"
  oidc_userinfo_endpt = "${local.authentik_base}/application/o/userinfo/"
  oidc_jwks_endpoint  = "${local.authentik_base}/application/o/${local.application_slug}/jwks/"
  authentik_api_url   = local.authentik_base

  # Full URL wins; else compose from platform icon_base_url + filename; else empty.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    var.icon_filename != "" ? "${var.base.authentik.icon_base_url}/${var.icon_filename}" :
    ""
  )
}
