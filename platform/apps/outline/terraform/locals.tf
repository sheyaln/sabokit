locals {
  slug             = "outline"
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

  oidc_callback_url = "https://${var.hostname}/auth/oidc.callback"
  app_url           = "https://${var.hostname}"

  # Bucket name must be globally unique across all Scaleway customers.
  # Convention: {secrets_namespace}-outline-attachments. Override via Scaleway dashboard if collision occurs.
  bucket_name = "${var.base.scaleway.secrets_namespace}-${local.slug}-attachments"
}
