# Nextcloud bootstrap admin password. Set on first install via
# NEXTCLOUD_ADMIN_PASSWORD. Once Nextcloud's installer has hashed it into the
# oc_users table, rotating here doesn't change the in-DB password — same
# ignore_changes treatment as a SECRET_KEY. To rotate, change the password
# in Nextcloud's admin UI then taint this resource.
resource "random_password" "admin" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false

  lifecycle {
    ignore_changes = all
  }
}

# Redis password. Used by Nextcloud for distributed locking + memcache.
# Rotating mid-flight orphans the locks in the existing Redis instance and
# the cluster needs a coordinated restart. Lock the value for the lifetime
# of the deployment; to rotate, taint AND restart the stack.
resource "random_password" "redis" {
  count   = var.enabled ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Nextcloud application secrets (admin bootstrap password, Redis password, OIDC + S3 bag)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    NEXTCLOUD_URL            = local.app_url
    NEXTCLOUD_TRUSTED_DOMAIN = var.hostname
    NEXTCLOUD_ADMIN_USER     = var.admin_username
    NEXTCLOUD_ADMIN_PASSWORD = random_password.admin[0].result
    REDIS_PASSWORD           = random_password.redis[0].result
    DEFAULT_PHONE_REGION     = var.default_phone_region
    TRUSTED_PROXIES          = var.trusted_proxies
    MAX_UPLOAD_SIZE_BYTES    = tostring(var.max_upload_size_bytes)

    OIDC_CLIENT_ID     = module.authentik[0].client_id
    OIDC_CLIENT_SECRET = module.authentik[0].client_secret
    OIDC_ISSUER_URL    = local.oidc_issuer_url
    OIDC_DISCOVERY_URL = "${local.oidc_issuer_url}.well-known/openid-configuration"
    OIDC_PROVIDER_NAME = "Authentik"
    OIDC_SCOPES        = "openid profile email"

    S3_ENDPOINT_HOST = replace(var.base.scaleway.object_storage_endpoint, "https://", "")
    S3_REGION        = var.base.scaleway.region
    S3_BUCKET        = module.data_bucket[0].name
    S3_ACCESS_KEY    = scaleway_iam_api_key.storage[0].access_key
    S3_SECRET_KEY    = scaleway_iam_api_key.storage[0].secret_key

    SMTP_FROM_EMAIL = var.smtp_from_email
  })

  lifecycle {
    # Admin + Redis passwords have ignore_changes upstream so re-applying with
    # the same plan produces the same JSON. Skipping the version replace
    # avoids "value differs" thrash when peripheral fields (OIDC client_secret
    # rotating underneath us) churn.
    ignore_changes = [data]
  }
}
