# Broadsheet encrypts every workspace secret with SECRET_KEY. Rotating it
# would break every encrypted secret in the database. ignore_changes locks
# the generated value for the lifetime of the deployment — to truly rotate,
# operators must taint this resource AND export-then-reimport every workspace.
resource "random_password" "secret_key" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 64
  special = false

  lifecycle {
    ignore_changes = all
  }
}

# Root-admin password. Operators sign in with this if OIDC is misconfigured.
# Once Broadsheet boots and the root user exists, rotating here doesn't change
# the in-DB password — same ignore_changes treatment.
resource "random_password" "root_admin" {
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
  description = "Broadsheet application secrets (SECRET_KEY, root admin, OIDC, S3, SMTP from-address)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

# In-place cutover: read the live bag and pin SECRET_KEY + ROOT_ADMIN_PASSWORD.
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
  _preserved          = (var.enabled && var.credentials_preserve) ? jsondecode(base64decode(data.scaleway_secret_version.preserved[0].data)) : {}
  secret_key          = var.enabled ? (var.credentials_preserve ? local._preserved.SECRET_KEY : random_password.secret_key[0].result) : ""
  root_admin_password = var.enabled ? (var.credentials_preserve ? local._preserved.ROOT_ADMIN_PASSWORD : random_password.root_admin[0].result) : ""
  app_secret_id       = var.enabled ? (var.credentials_preserve ? data.scaleway_secret.preserved[0].id : scaleway_secret.app[0].id) : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    SECRET_KEY          = local.secret_key
    API_ENDPOINT        = local.api_endpoint
    ROOT_EMAIL          = var.root_admin_email
    ROOT_ADMIN_EMAIL    = var.root_admin_email
    ROOT_ADMIN_PASSWORD = local.root_admin_password

    OIDC_ENABLED          = "true"
    OIDC_ISSUER_URL       = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/"
    OIDC_CLIENT_ID        = module.authentik[0].client_id
    OIDC_CLIENT_SECRET    = module.authentik[0].client_secret
    OIDC_AUTO_PROVISION   = tostring(var.oidc_auto_provision)
    OIDC_ALLOW_MAGIC_CODE = tostring(var.oidc_allow_magic_code)

    S3_PROVIDER   = "scaleway"
    S3_ENDPOINT   = var.base.scaleway.object_storage_endpoint
    S3_BUCKET     = module.files_bucket[0].name
    S3_ACCESS_KEY = scaleway_iam_api_key.storage[0].access_key
    S3_SECRET_KEY = scaleway_iam_api_key.storage[0].secret_key
    S3_REGION     = var.base.scaleway.region

    SMTP_FROM_EMAIL = var.smtp_from_email
  })

  lifecycle {
    # The secret version is immutable after the first apply: SECRET_KEY +
    # ROOT_ADMIN_PASSWORD have ignore_changes upstream, so re-applying with
    # the same plan produces the same JSON. Skipping the version replace
    # avoids "value differs" thrash when other fields (OIDC client_secret)
    # rotate underneath us.
    ignore_changes = [data]
  }
}
