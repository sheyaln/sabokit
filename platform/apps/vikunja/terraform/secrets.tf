# JWT signing secret for Vikunja's API tokens. Generated once, immutable.
resource "random_password" "jwt_secret" {
  count   = var.enabled ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    # Required for `terraform import`: imported state has null length/special
    # which would otherwise conflict and trigger force-replacement.
    ignore_changes = all
  }
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Vikunja application secrets (JWT signing key, OIDC bag)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

locals {
  jwt_secret    = var.enabled ? (random_password.jwt_secret[0].result) : ""
  app_secret_id = var.enabled ? (scaleway_secret.app[0].id) : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    VIKUNJA_SERVICE_JWTSECRET = local.jwt_secret

    VIKUNJA_AUTH_OPENID_CLIENTID     = module.authentik[0].client_id
    VIKUNJA_AUTH_OPENID_CLIENTSECRET = module.authentik[0].client_secret
    VIKUNJA_AUTH_OPENID_AUTHURL      = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/"
    VIKUNJA_AUTH_OPENID_LOGOUTURL    = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/end-session/"

    # SMTP from-address. Actual SMTP host/port/username/password come from
    # the platform-wide smtp-config secret (looked up by the Ansible role
    # when smtp_secret_name is non-empty).
    VIKUNJA_MAILER_FROMEMAIL = var.smtp_from_email
  })

  lifecycle {
    # Scaleway's API doesn't return secret values on read; after `terraform
    # import` the refreshed `data` is null and re-render forces replacement,
    # rotating VIKUNJA_SERVICE_JWTSECRET and invalidating every issued token.
    # Lock the version. Rotate by tainting this resource.
    ignore_changes = [data]
  }
}
