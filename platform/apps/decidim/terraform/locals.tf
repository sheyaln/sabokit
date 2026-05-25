locals {
  slug             = "decidim"
  application_slug = var.application_slug != "" ? var.application_slug : local.slug

  authorized_groups = var.enabled ? (
    var.tier_cascade_enabled
    ? var.base.authentik.tier_cascade[var.tier_access_level]
    : merge(
      { (var.access_level) = var.base.authentik.groups[var.access_level] },
      var.extra_authorized_groups,
    )
  ) : {}

  # Decidim's decidim-omniauth-oauth2 plugin posts back to /users/auth/oauth2_authentik/callback.
  oidc_callback_url = "https://${var.hostname}/users/auth/oauth2_authentik/callback"
  app_url           = "https://${var.hostname}"

  organization_admin_email = var.organization_admin_email != "" ? var.organization_admin_email : var.system_admin_email

  # Reference prefix: Decidim stamps these on internal record IDs. Fall back to
  # the first three letters of the org name uppercased when the caller leaves
  # the variable empty; cheaper than asking every consumer to invent one.
  reference_prefix = var.organization_reference_prefix != "" ? var.organization_reference_prefix : upper(substr(replace(var.organization_name, "/[^A-Za-z]/", ""), 0, 3))

  # Bucket name must be globally unique across all Scaleway customers.
  bucket_name = "${var.base.scaleway.secrets_namespace}-${local.slug}-uploads"

  # Full URL wins; else compose from platform icon_base_url + filename; else empty.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    var.icon_filename != "" ? "${var.base.authentik.icon_base_url}/${var.icon_filename}" :
    ""
  )
}
