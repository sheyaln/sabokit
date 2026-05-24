locals {
  slug = "wazuh"

  authorized_groups = var.enabled ? merge(
    { (var.access_level) = var.base.authentik.groups[var.access_level] },
    var.extra_authorized_groups,
  ) : {}

  app_url = "https://${var.hostname}"

  # Dashboard's OIDC callback. opensearch-security's openid auth handler
  # uses /auth/openid/login as its callback path.
  oidc_callback_url = "https://${var.hostname}/auth/openid/login"

  # OIDC discovery URL on Authentik for the wazuh app.
  oidc_discovery_url = "https://${var.base.authentik.gateway_domain}/application/o/${local.slug}/.well-known/openid-configuration"
}
