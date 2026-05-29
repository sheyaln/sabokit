locals {
  slug             = "nextcloud"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  # Authorized groups = the consumer's explicit group-name list, resolved to IDs
  # via base.authentik.groups. Map keys are the group names (static at plan), so
  # the leaf module's for_each plans before identity-apply fills the UUIDs.
  authorized_groups = var.enabled ? {
    for g in var.authorized_groups : g => var.base.authentik.groups[g]
  } : {}

  # Nextcloud's user_oidc app expects the callback at /apps/user_oidc/code.
  oidc_callback_url = "https://${var.hostname}/apps/user_oidc/code"
  oidc_issuer_url   = "https://${var.base.authentik.identity_domain}/application/o/${local.application_slug}/"
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
