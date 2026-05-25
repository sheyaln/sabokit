locals {
  slug             = "wazuh"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  app_url = "https://${var.hostname}"

  # Dashboard's OIDC callback. opensearch-security's openid auth handler
  # uses /auth/openid/login as its callback path.
  oidc_callback_url = "https://${var.hostname}/auth/openid/login"

  # OIDC discovery URL on Authentik for the wazuh app.
  oidc_discovery_url = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/.well-known/openid-configuration"
}
