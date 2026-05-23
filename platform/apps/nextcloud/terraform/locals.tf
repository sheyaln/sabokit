locals {
  slug = "nextcloud"

  # Authorized groups = the access-level group from base + any extras.
  # Map keys are static role names so for_each can plan before identity-apply
  # has populated the actual group UUIDs.
  authorized_groups = var.enabled ? merge(
    { (var.access_level) = var.base.authentik.groups[var.access_level] },
    var.extra_authorized_groups,
  ) : {}

  # Nextcloud's user_oidc app expects the callback at /apps/user_oidc/code.
  oidc_callback_url = "https://${var.hostname}/apps/user_oidc/code"
  oidc_issuer_url   = "https://${var.base.authentik.gateway_domain}/application/o/${local.slug}/"
  app_url           = "https://${var.hostname}"
  onlyoffice_url    = "https://${var.onlyoffice_hostname}"
  talk_url          = "https://${var.talk_hostname}"

  # Bucket name must be globally unique across all Scaleway customers.
  # Convention: {secrets_namespace}-nextcloud-data. Override via Scaleway dashboard if collision occurs.
  bucket_name = "${var.base.scaleway.secrets_namespace}-${local.slug}-data"
}
