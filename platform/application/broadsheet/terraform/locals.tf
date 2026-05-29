locals {
  slug             = "broadsheet"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  authorized_groups = var.enabled ? {
    for g in var.authorized_groups : g => var.base.authentik.groups[g]
  } : {}

  oidc_callback_url = "https://${var.hostname}/api/auth/oidc/callback"
  app_url           = "https://${var.hostname}"
  api_endpoint      = local.app_url

  # Bucket: broadsheet stores marketing assets (templates, attachments). Globally
  # unique per Scaleway, hence the secrets_namespace prefix. Override consults
  # var.bucket_name_override for legacy-bucket import without force-replace.
  bucket_name = var.bucket_name_override != "" ? var.bucket_name_override : "${var.base.scaleway.secrets_namespace}-${local.slug}-files"

  # Full URL wins; else compose from platform icon_base_url + filename; else empty.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    var.icon_filename != "" ? "${var.base.authentik.icon_base_url}/${var.icon_filename}" :
    ""
  )
}
