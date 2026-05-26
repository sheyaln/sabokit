# Single Scaleway secret holding everything the Ansible role needs to render
# Steward's .env file. The DB credentials live in a separate secret managed by
# the postgres_database module (Steward reads both at deploy time).

resource "random_id" "django_secret_key" {
  count       = var.enabled && !var.credentials_preserve ? 1 : 0
  byte_length = 50
}

resource "scaleway_secret" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Steward application secrets (Django SECRET_KEY, OIDC creds, Authentik API token)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

# In-place cutover: read the live bag and pin DJANGO_SECRET_KEY + the
# Authentik service-account API token to the existing values.
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
  django_secret_key   = var.enabled ? (var.credentials_preserve ? local._preserved.DJANGO_SECRET_KEY : random_id.django_secret_key[0].b64_url) : ""
  authentik_api_token = var.enabled ? authentik_token.service_steward[0].key : ""
  app_secret_id       = var.enabled ? (var.credentials_preserve ? data.scaleway_secret.preserved[0].id : scaleway_secret.app[0].id) : ""
  app_secret_name     = var.enabled ? (var.credentials_preserve ? data.scaleway_secret.preserved[0].name : scaleway_secret.app[0].name) : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled && !var.credentials_preserve ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    DJANGO_SECRET_KEY    = local.django_secret_key
    DJANGO_ALLOWED_HOSTS = var.hostname

    APP_URL = local.app_url

    OIDC_RP_CLIENT_ID              = module.authentik[0].client_id
    OIDC_RP_CLIENT_SECRET          = module.authentik[0].client_secret
    OIDC_OP_AUTHORIZATION_ENDPOINT = local.oidc_auth_endpoint
    OIDC_OP_TOKEN_ENDPOINT         = local.oidc_token_endpoint
    OIDC_OP_USER_ENDPOINT          = local.oidc_userinfo_endpt
    OIDC_OP_JWKS_ENDPOINT          = local.oidc_jwks_endpoint
    OIDC_RP_SIGN_ALGO              = "RS256"
    OIDC_RP_SCOPES                 = "openid profile email groups"

    AUTHENTIK_API_URL     = local.authentik_api_url
    AUTHENTIK_API_TOKEN   = local.authentik_api_token
    AUTHENTIK_ADMIN_GROUP = var.admin_group_name
    AUTHENTIK_INVITE_FLOW = var.invite_flow_slug
  })

  lifecycle {
    # Scaleway's API doesn't return secret values on read; after `terraform
    # import` the refreshed `data` is null and re-render forces replacement.
    # Lock the version. Rotate by tainting this resource.
    ignore_changes = [data]
  }
}
