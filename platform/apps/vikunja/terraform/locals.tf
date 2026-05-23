locals {
  slug = "vikunja"

  authorized_groups = var.enabled ? merge(
    { (var.access_level) = var.base.authentik.groups[var.access_level] },
    var.extra_authorized_groups,
  ) : {}

  oidc_callback_url = "https://${var.hostname}/auth/openid/authentik"
  app_url           = "https://${var.hostname}"
}
