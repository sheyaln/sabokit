# Single Scaleway secret holding everything the Ansible role needs to render
# Steward's .env file. The DB credentials live in a separate secret managed by
# the postgres_database module (Steward reads both at deploy time).

resource "random_id" "django_secret_key" {
  count       = var.enabled ? 1 : 0
  byte_length = 50
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "Steward application secrets (Django SECRET_KEY, OIDC creds, Authentik API token)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    DJANGO_SECRET_KEY    = random_id.django_secret_key[0].b64_url
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
    AUTHENTIK_API_TOKEN   = authentik_token.service_steward[0].key
    AUTHENTIK_ADMIN_GROUP = var.admin_group_name
    AUTHENTIK_INVITE_FLOW = var.invite_flow_slug
  })
}
