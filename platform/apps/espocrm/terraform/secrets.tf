# Admin password for the local fallback account. Locked in after first apply —
# regenerating would diverge from the in-database password without any
# automated reconciliation, so operators rotate it manually if needed.
resource "random_password" "admin" {
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
  description = "EspoCRM application secrets (admin fallback password, OIDC bag, SMTP from-address)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

# In-place cutover: read the live bag and pin ADMIN_PASSWORD.
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
  admin_password = var.enabled ? (var.credentials_preserve ? local._preserved.ADMIN_PASSWORD : try(var.credentials_preserve_source.ADMIN_PASSWORD, random_password.admin[0].result)) : ""
  app_secret_id  = var.enabled ? (var.credentials_preserve ? data.scaleway_secret.preserved[0].id : scaleway_secret.app[0].id) : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    SITE_URL       = local.app_url
    ADMIN_USERNAME = var.admin_username
    ADMIN_PASSWORD = local.admin_password

    OIDC_CLIENT_ID              = module.authentik[0].client_id
    OIDC_CLIENT_SECRET          = module.authentik[0].client_secret
    OIDC_AUTHORIZATION_ENDPOINT = "https://${var.base.authentik.gateway_domain}/application/o/authorize/"
    OIDC_TOKEN_ENDPOINT         = "https://${var.base.authentik.gateway_domain}/application/o/token/"
    OIDC_USERINFO_ENDPOINT      = "https://${var.base.authentik.gateway_domain}/application/o/userinfo/"
    OIDC_JWKS_ENDPOINT          = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/jwks/"
    OIDC_REDIRECT_URI           = local.oidc_callback_url
    OIDC_LOGOUT_URL             = local.oidc_logout_url

    SMTP_FROM_EMAIL = var.smtp_from_email
  })

  # Admin password is locked via ignore_changes upstream; OIDC client_secret
  # rotates on Authentik's side without warning. Skip the version replace to
  # avoid thrash — operators force a rotation by tainting this resource.
  lifecycle {
    ignore_changes = [data]
  }
}
