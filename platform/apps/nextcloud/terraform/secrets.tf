# Nextcloud bootstrap admin password. Set on first install via
# NEXTCLOUD_ADMIN_PASSWORD. Once Nextcloud's installer has hashed it into the
# oc_users table, rotating here doesn't change the in-DB password — same
# ignore_changes treatment as a SECRET_KEY. To rotate, change the password
# in Nextcloud's admin UI then taint this resource.
resource "random_password" "admin" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
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
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

# OnlyOffice JWT secret. Signs every edit-session payload Nextcloud hands the
# document server; the two sides MUST agree on the same value. Rotating
# in-flight breaks every in-progress edit until both containers re-read it AND
# the configure script re-runs to push it into the Nextcloud onlyoffice app's
# config. Lock the value the same way as Redis/admin.
resource "random_password" "onlyoffice_jwt" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

# OnlyOffice secure-link secret. Signs cache-invalidation URLs the document
# server hands its own nginx; cosmetic for single-instance, but the image
# refuses to start cleanly without it.
resource "random_password" "onlyoffice_secure_link" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 32
  special = false

  lifecycle {
    ignore_changes = all
  }
}

# Talk HPB shared secrets. Three separate values because the Nextcloud Talk
# server, the standalone signaling server, and eturnal all do their own
# HMAC-based handshakes. They are NOT interchangeable; mixing them up causes
# silent auth failures (calls connect but media never flows). All three are
# locked post-bootstrap — rotating requires restarting the HPB container AND
# re-running the configure script so Nextcloud's spreed app picks up the new
# values.
resource "random_password" "talk_turn_secret" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "random_password" "talk_signaling_secret" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "random_password" "talk_internal_secret" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "scaleway_secret" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Nextcloud application secrets (admin bootstrap password, Redis password, OIDC + S3 bag)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

# In-place cutover: read the live bag and pin every generated credential to
# the existing value via one decode + per-credential local.
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
  _preserved = (var.enabled && var.credentials_preserve) ? jsondecode(base64decode(data.scaleway_secret_version.preserved[0].data)) : {}
  # credentials_preserve_source (greenfield-to-v3): supplied values
  # shadow random_* without count-gating them, so state stays stable.
  admin_password         = var.enabled ? (var.credentials_preserve ? local._preserved.NEXTCLOUD_ADMIN_PASSWORD : try(var.credentials_preserve_source.NEXTCLOUD_ADMIN_PASSWORD, random_password.admin[0].result)) : ""
  redis_password         = var.enabled ? (var.credentials_preserve ? local._preserved.REDIS_PASSWORD : try(var.credentials_preserve_source.REDIS_PASSWORD, random_password.redis[0].result)) : ""
  onlyoffice_jwt_secret  = var.enabled ? (var.credentials_preserve ? local._preserved.ONLYOFFICE_JWT_SECRET : try(var.credentials_preserve_source.ONLYOFFICE_JWT_SECRET, random_password.onlyoffice_jwt[0].result)) : ""
  onlyoffice_secure_link = var.enabled ? (var.credentials_preserve ? local._preserved.ONLYOFFICE_SECURE_LINK : try(var.credentials_preserve_source.ONLYOFFICE_SECURE_LINK, random_password.onlyoffice_secure_link[0].result)) : ""
  talk_turn_secret       = var.enabled ? (var.credentials_preserve ? local._preserved.TALK_TURN_SECRET : try(var.credentials_preserve_source.TALK_TURN_SECRET, random_password.talk_turn_secret[0].result)) : ""
  talk_signaling_secret  = var.enabled ? (var.credentials_preserve ? local._preserved.TALK_SIGNALING_SECRET : try(var.credentials_preserve_source.TALK_SIGNALING_SECRET, random_password.talk_signaling_secret[0].result)) : ""
  talk_internal_secret   = var.enabled ? (var.credentials_preserve ? local._preserved.TALK_INTERNAL_SECRET : try(var.credentials_preserve_source.TALK_INTERNAL_SECRET, random_password.talk_internal_secret[0].result)) : ""
  app_secret_id          = var.enabled ? (var.credentials_preserve ? data.scaleway_secret.preserved[0].id : scaleway_secret.app[0].id) : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    NEXTCLOUD_URL            = local.app_url
    NEXTCLOUD_TRUSTED_DOMAIN = var.hostname
    NEXTCLOUD_ADMIN_USER     = var.admin_username
    NEXTCLOUD_ADMIN_PASSWORD = local.admin_password
    REDIS_PASSWORD           = local.redis_password
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

    # OnlyOffice ↔ Nextcloud trust handshake. ONLYOFFICE_PUBLIC_URL is what
    # browsers load the editor from; ONLYOFFICE_INTERNAL_URL is the in-stack
    # name Nextcloud uses for server-to-server callbacks, which avoids
    # bouncing off the public ingress for every save.
    ONLYOFFICE_PUBLIC_URL   = local.onlyoffice_url
    ONLYOFFICE_INTERNAL_URL = "http://nextcloud-onlyoffice/"
    ONLYOFFICE_STORAGE_URL  = "http://nextcloud-app/"
    ONLYOFFICE_JWT_SECRET   = local.onlyoffice_jwt_secret
    ONLYOFFICE_SECURE_LINK  = local.onlyoffice_secure_link

    # Talk HPB. TALK_HOST is the public name clients connect to for both
    # WSS signaling and (separately) the eturnal TURN server on UDP/TCP 3478.
    TALK_HOST             = var.talk_hostname
    TALK_TURN_PORT        = tostring(var.talk_turn_port)
    TALK_RELAY_PORT_MIN   = tostring(var.talk_relay_port_min)
    TALK_RELAY_PORT_MAX   = tostring(var.talk_relay_port_max)
    TALK_TURN_SECRET      = local.talk_turn_secret
    TALK_SIGNALING_SECRET = local.talk_signaling_secret
    TALK_INTERNAL_SECRET  = local.talk_internal_secret
  })

  lifecycle {
    # Admin + Redis passwords have ignore_changes upstream so re-applying with
    # the same plan produces the same JSON. Skipping the version replace
    # avoids "value differs" thrash when peripheral fields (OIDC client_secret
    # rotating underneath us) churn.
    ignore_changes = [data]
  }
}
