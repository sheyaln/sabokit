locals {
  slug             = "nextcloud"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  # Authorized groups = the access-level group from base + any extras.
  # Map keys are static role names so for_each can plan before identity-apply
  # has populated the actual group UUIDs.
  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  # Nextcloud's user_oidc app expects the callback at /apps/user_oidc/code.
  oidc_callback_url = "https://${var.hostname}/apps/user_oidc/code"
  oidc_issuer_url   = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/"
  app_url           = "https://${var.hostname}"
  onlyoffice_url    = "https://${var.onlyoffice_hostname}"
  talk_url          = "https://${var.talk_hostname}"

  # Bucket name must be globally unique across all Scaleway customers.
  # Convention: {secrets_namespace}-nextcloud-data. Override consults
  # var.bucket_name_override for legacy-bucket import without force-replace.
  bucket_name = var.bucket_name_override != "" ? var.bucket_name_override : "${var.base.scaleway.secrets_namespace}-${local.slug}-data"

  # Full URL wins; else compose from platform icon_base_url + filename; else empty.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    var.icon_filename != "" ? "${var.base.authentik.icon_base_url}/${var.icon_filename}" :
    ""
  )
}
