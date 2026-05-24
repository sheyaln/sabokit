locals {
  slug = "jitsi"

  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  # The OIDC adapter handles the /oidc/* callback. Strict-mode redirect URI
  # binds Authentik to one exact URL; the adapter's /oidc/redirect endpoint.
  oidc_callback_url = "https://${var.hostname}/oidc/redirect"
  app_url           = "https://${var.hostname}"
}
