# Grafana admin password (break-glass for when OIDC breaks). Pinned: rotating
# requires `grafana-cli admin reset-admin-password` inside the container.

resource "random_password" "admin" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 32
  special = false
}

resource "scaleway_secret" "app" {
  count       = var.enabled && !var.credentials_preserve ? 1 : 0
  name        = "${local.slug}-app-secrets"
  description = "Grafana admin password + OIDC bag"
  tags        = ["automated", local.slug]
  type        = "key_value"
}

# In-place cutover: read the live bag and pin GRAFANA_ADMIN_PASSWORD.
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
  _preserved     = (var.enabled && var.credentials_preserve) ? jsondecode(base64decode(data.scaleway_secret_version.preserved[0].data)) : {}
  admin_password = var.enabled ? (var.credentials_preserve ? local._preserved.GRAFANA_ADMIN_PASSWORD : random_password.admin[0].result) : ""
  app_secret_id  = var.enabled ? (var.credentials_preserve ? data.scaleway_secret.preserved[0].id : scaleway_secret.app[0].id) : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    GRAFANA_ADMIN_USER     = var.admin_username
    GRAFANA_ADMIN_PASSWORD = local.admin_password
    OIDC_CLIENT_ID         = module.authentik[0].client_id
    OIDC_CLIENT_SECRET     = module.authentik[0].client_secret
    OIDC_AUTH_URL          = "https://${var.base.authentik.gateway_domain}/application/o/authorize/"
    OIDC_TOKEN_URL         = "https://${var.base.authentik.gateway_domain}/application/o/token/"
    OIDC_API_URL           = "https://${var.base.authentik.gateway_domain}/application/o/userinfo/"
    OIDC_SIGNOUT_URL       = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/end-session/"
  })

  lifecycle {
    # OIDC client_secret can rotate underneath without forcing a new version.
    ignore_changes = [data]
  }
}
