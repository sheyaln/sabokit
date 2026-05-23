# JWT signing secret for Vikunja's API tokens. Generated once, immutable.
resource "random_password" "jwt_secret" {
  count   = var.enabled ? 1 : 0
  length  = 48
  special = false
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Vikunja application secrets (JWT signing key, OIDC bag)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    VIKUNJA_SERVICE_JWTSECRET = random_password.jwt_secret[0].result

    VIKUNJA_AUTH_OPENID_CLIENTID     = module.authentik[0].client_id
    VIKUNJA_AUTH_OPENID_CLIENTSECRET = module.authentik[0].client_secret
    VIKUNJA_AUTH_OPENID_AUTHURL      = "https://${var.base.authentik.gateway_domain}/application/o/${local.slug}/"
    VIKUNJA_AUTH_OPENID_LOGOUTURL    = "https://${var.base.authentik.gateway_domain}/application/o/${local.slug}/end-session/"

    # SMTP from-address. Actual SMTP host/port/username/password come from
    # the platform-wide smtp-config secret (looked up by the Ansible role
    # when smtp_secret_name is non-empty).
    VIKUNJA_MAILER_FROMEMAIL = var.smtp_from_email
  })
}
