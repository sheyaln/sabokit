locals {
  slug             = "espocrm"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  # EspoCRM's OIDC redirect URI is the site root — Espo intercepts the
  # /?action=oauthCallback pattern internally rather than exposing a dedicated path.
  oidc_callback_url = "https://${var.hostname}/oauth-callback.php"
  oidc_logout_url   = "https://${var.base.authentik.identity_domain}/application/o/${local.application_slug}/end-session/"
  app_url           = "https://${var.hostname}"

  # Full URL wins; else compose from platform icon_base_url + filename; else empty.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    var.icon_filename != "" ? "${var.base.authentik.icon_base_url}/${var.icon_filename}" :
    ""
  )
}
