locals {
  slug             = "jitsi"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

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

  # Full URL wins; else compose from platform icon_base_url + filename; else empty.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    var.icon_filename != "" ? "${var.base.authentik.icon_base_url}/${var.icon_filename}" :
    ""
  )
}
