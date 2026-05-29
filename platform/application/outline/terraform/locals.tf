locals {
  slug             = "outline"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  # Authorized groups = the consumer's explicit group-name list, resolved to IDs
  # via base.authentik.groups. Map keys are the group names (static at plan), so
  # the leaf module's for_each plans before identity-apply fills the UUIDs.
  authorized_groups = var.enabled ? {
    for g in var.authorized_groups : g => var.base.authentik.groups[g]
  } : {}

  oidc_callback_url = "https://${var.hostname}/auth/oidc.callback"
  app_url           = "https://${var.hostname}"

  # Full URL wins; else compose from platform icon_base_url + filename; else empty.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    var.icon_filename != "" ? "${var.base.authentik.icon_base_url}/${var.icon_filename}" :
    ""
  )

  # Bucket name must be globally unique across all Scaleway customers.
  # Convention: {secrets_namespace}-outline-attachments. Override consults
  # var.bucket_name_override for legacy-bucket import without force-replace.
  bucket_name = var.bucket_name_override != "" ? var.bucket_name_override : "${var.base.scaleway.secrets_namespace}-${local.slug}-attachments"
}
