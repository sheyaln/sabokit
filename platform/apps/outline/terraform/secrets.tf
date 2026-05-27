# App SECRET_KEY and UTILS_SECRET (must be 32-byte hex strings per Outline docs).
# Stored in Scaleway Secret Manager so the Ansible role can pull them.

resource "random_id" "secret_key" {
  count       = var.enabled ? 1 : 0
  byte_length = 32
}

resource "random_id" "utils_secret" {
  count       = var.enabled ? 1 : 0
  byte_length = 32
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Outline application secrets (SECRET_KEY, UTILS_SECRET, OIDC + S3 bag)"
  tags        = ["automated", local.slug]
  type        = "key_value"
}

locals {
  secret_key    = var.enabled ? random_id.secret_key[0].hex : ""
  utils_secret  = var.enabled ? random_id.utils_secret[0].hex : ""
  app_secret_id = var.enabled ? scaleway_secret.app[0].id : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    SECRET_KEY     = local.secret_key
    UTILS_SECRET   = local.utils_secret
    OUTLINE_URL    = local.app_url
    OIDC_CLIENT_ID = module.authentik[0].client_id
    # OIDC_CLIENT_SECRET is also available at scaleway secret module.authentik[0].scaleway_secret_id;
    # we embed here too for convenience of the ansible role.
    OIDC_CLIENT_SECRET  = module.authentik[0].client_secret
    OIDC_AUTH_URI       = "https://${var.base.authentik.gateway_domain}/application/o/authorize/"
    OIDC_TOKEN_URI      = "https://${var.base.authentik.gateway_domain}/application/o/token/"
    OIDC_USERINFO_URI   = "https://${var.base.authentik.gateway_domain}/application/o/userinfo/"
    OIDC_LOGOUT_URI     = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/end-session/"
    OIDC_USERNAME_CLAIM = var.oidc_username_claim
    OIDC_DISPLAY_NAME   = "Authentik"
    OIDC_SCOPES         = "openid profile email"

    AWS_REGION                   = var.base.scaleway.region
    AWS_S3_FORCE_PATH_STYLE      = "true"
    AWS_S3_UPLOAD_BUCKET_NAME    = module.attachments_bucket[0].name
    AWS_S3_UPLOAD_BUCKET_URL     = var.base.scaleway.object_storage_endpoint
    AWS_ACCESS_KEY_ID            = scaleway_iam_api_key.storage[0].access_key
    AWS_SECRET_ACCESS_KEY        = scaleway_iam_api_key.storage[0].secret_key
    AWS_S3_ACL                   = var.storage_bucket_acl
    FILE_STORAGE_UPLOAD_MAX_SIZE = tostring(var.max_upload_size_bytes)

    SMTP_FROM_EMAIL = var.smtp_from_email
  })

  lifecycle {
    # Scaleway's API doesn't return secret values on read; after `terraform
    # import` the refreshed `data` is null and re-render forces replacement,
    # rotating SECRET_KEY/UTILS_SECRET and breaking every encrypted column
    # in the DB. Lock the version. Rotate by tainting this resource.
    ignore_changes = [data]
  }
}
