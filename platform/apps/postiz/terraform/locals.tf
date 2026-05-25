locals {
  slug = "postiz"

  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  # Postiz's OIDC redirect path is the standard NextAuth-style callback.
  oidc_callback_url = "https://${var.hostname}/settings"
  app_url           = "https://${var.hostname}"
}
