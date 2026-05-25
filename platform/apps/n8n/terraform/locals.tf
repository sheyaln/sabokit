locals {
  slug             = "n8n"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  app_url           = "https://${var.hostname}"
  oidc_callback_url = "${local.app_url}/auth/oidc/callback"
}
