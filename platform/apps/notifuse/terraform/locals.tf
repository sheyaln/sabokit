locals {
  slug             = "notifuse"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  oidc_callback_url = "https://${var.hostname}/auth/oidc/callback"
  app_url           = "https://${var.hostname}"
  api_endpoint      = local.app_url

  # Bucket: notifuse stores marketing assets (templates, attachments). Globally
  # unique per Scaleway, hence the secrets_namespace prefix.
  bucket_name = "${var.base.scaleway.secrets_namespace}-${local.slug}-files"
}
