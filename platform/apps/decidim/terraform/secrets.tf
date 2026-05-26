# Rails SECRET_KEY_BASE — encrypts session cookies and signed cookies. Rotating
# it invalidates every existing session AND every Active Record encrypted
# attribute Decidim has stored. Lock to the first-applied value; to truly
# rotate, taint this resource and accept the session-invalidation blast radius.
resource "random_password" "secret_key_base" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 64
  special = false

  lifecycle {
    ignore_changes = all
  }
}

# /system superuser password. Once Decidim's db-init step has created the row,
# rotating here doesn't change what's in the DB — same ignore_changes treatment.
resource "random_password" "system_admin" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 32
  special = true

  lifecycle {
    ignore_changes = all
  }
}

# Organization-admin password, applied alongside the system admin during seed.
resource "random_password" "organization_admin" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 32
  special = true

  lifecycle {
    ignore_changes = all
  }
}

resource "scaleway_secret" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Decidim application secrets (SECRET_KEY_BASE, system + org admin, OIDC, S3 keys, SMTP from-address)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

# In-place cutover: read the live bag and pin all three preserved secrets.
data "scaleway_secret" "preserved" {
  count = var.enabled && var.credentials_preserve ? 1 : 0
  name  = "${local.slug}-app-secrets"
}

data "scaleway_secret_version" "preserved" {
  count     = var.enabled && var.credentials_preserve ? 1 : 0
  secret_id = data.scaleway_secret.preserved[0].id
  revision  = "latest"
}

locals {
  _preserved                  = (var.enabled && var.credentials_preserve) ? jsondecode(base64decode(data.scaleway_secret_version.preserved[0].data)) : {}
  secret_key_base             = var.enabled ? (var.credentials_preserve ? local._preserved.SECRET_KEY_BASE : random_password.secret_key_base[0].result) : ""
  system_admin_password       = var.enabled ? (var.credentials_preserve ? local._preserved.DECIDIM_SYSTEM_PASSWORD : random_password.system_admin[0].result) : ""
  organization_admin_password = var.enabled ? (var.credentials_preserve ? local._preserved.DECIDIM_ORG_ADMIN_PASSWORD : random_password.organization_admin[0].result) : ""
  app_secret_id               = var.enabled ? (var.credentials_preserve ? data.scaleway_secret.preserved[0].id : scaleway_secret.app[0].id) : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    SECRET_KEY_BASE = local.secret_key_base
    DECIDIM_HOST    = var.hostname
    DECIDIM_APP_URL = local.app_url

    DECIDIM_SYSTEM_EMAIL    = var.system_admin_email
    DECIDIM_SYSTEM_PASSWORD = local.system_admin_password

    DECIDIM_ORG_NAME             = var.organization_name
    DECIDIM_ORG_REFERENCE_PREFIX = local.reference_prefix
    DECIDIM_DEFAULT_LOCALE       = var.default_locale
    DECIDIM_AVAILABLE_LOCALES    = join(",", var.available_locales)

    DECIDIM_ORG_ADMIN_EMAIL    = local.organization_admin_email
    DECIDIM_ORG_ADMIN_PASSWORD = local.organization_admin_password

    OIDC_CLIENT_ID     = module.authentik[0].client_id
    OIDC_CLIENT_SECRET = module.authentik[0].client_secret
    OIDC_AUTH_URI      = "https://${var.base.authentik.gateway_domain}/application/o/authorize/"
    OIDC_TOKEN_URI     = "https://${var.base.authentik.gateway_domain}/application/o/token/"
    OIDC_USERINFO_URI  = "https://${var.base.authentik.gateway_domain}/application/o/userinfo/"
    OIDC_LOGOUT_URI    = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/end-session/"
    OIDC_ISSUER_URL    = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/"
    OIDC_SCOPES        = "openid profile email"

    AWS_REGION              = var.base.scaleway.region
    AWS_S3_ENDPOINT         = var.base.scaleway.object_storage_endpoint
    AWS_S3_BUCKET           = module.uploads_bucket[0].name
    AWS_S3_FORCE_PATH_STYLE = "true"
    AWS_ACCESS_KEY_ID       = scaleway_iam_api_key.storage[0].access_key
    AWS_SECRET_ACCESS_KEY   = scaleway_iam_api_key.storage[0].secret_key
    AWS_S3_ACL              = var.storage_bucket_acl
    UPLOAD_MAX_SIZE_BYTES   = tostring(var.max_upload_size_bytes)

    SMTP_FROM_EMAIL = var.smtp_from_email
  })

  lifecycle {
    # SECRET_KEY_BASE + admin passwords have ignore_changes upstream, so a
    # re-render of the same plan produces the same JSON. Skipping the version
    # replace avoids thrash when downstream values (OIDC client_secret) rotate.
    ignore_changes = [data]
  }
}
