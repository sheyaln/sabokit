# N8N_ENCRYPTION_KEY encrypts every saved credential in the n8n database
# (Slack tokens, API keys, OAuth refresh tokens — everything a workflow uses).
# Rotating it bricks the entire credential store: workflows still run their
# nodes but every connected service auth fails until manually re-entered.
# ignore_changes locks the generated value for the lifetime of the deployment.
# To truly rotate, taint this resource AND plan to re-enter every credential.
resource "random_password" "encryption_key" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

# Shared token between n8n and the n8nio/runners sidecar — task broker auth.
# Same lifecycle treatment: rotating it mid-run kills any in-flight task.
resource "random_password" "runners_auth_token" {
  count   = var.enabled && !var.credentials_preserve ? 1 : 0
  length  = 48
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "scaleway_secret" "app" {
  count = var.enabled ? 1 : 0

  name        = "${local.slug}-app-secrets"
  description = "n8n application secrets (encryption key, runners auth token, OIDC bag)."
  tags        = ["automated", local.slug]
  type        = "key_value"
}

# In-place cutover: read the live bag and pin ENCRYPTION_KEY +
# RUNNERS_AUTH_TOKEN + the Authentik service-account API token to the existing
# values.
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
  encryption_key      = var.enabled ? (var.credentials_preserve ? local._preserved.N8N_ENCRYPTION_KEY : random_password.encryption_key[0].result) : ""
  runners_auth_token  = var.enabled ? (var.credentials_preserve ? local._preserved.N8N_RUNNERS_AUTH_TOKEN : random_password.runners_auth_token[0].result) : ""
  authentik_api_token = var.enabled ? authentik_token.service_n8n[0].key : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    N8N_ENCRYPTION_KEY     = local.encryption_key
    N8N_RUNNERS_AUTH_TOKEN = local.runners_auth_token

    WEBHOOK_URL = local.app_url

    OIDC_ISSUER_URL    = "https://${var.base.authentik.gateway_domain}/application/o/${local.application_slug}/"
    OIDC_CLIENT_ID     = module.authentik[0].client_id
    OIDC_CLIENT_SECRET = module.authentik[0].client_secret
    OIDC_REDIRECT_URI  = local.oidc_callback_url
    OIDC_ADMIN_GROUP   = var.n8n_admin_group_name

    # Server-to-server Authentik API access for workflows that need to read
    # users/groups, post events, etc. Same shape as steward's bag.
    AUTHENTIK_API_URL   = "https://${var.base.authentik.gateway_domain}/api/v3"
    AUTHENTIK_API_TOKEN = local.authentik_api_token
  })

  # Same logic as notifuse: encryption_key + runners_auth_token are ignore_changes,
  # so re-applying with the same plan produces identical JSON. Skipping replace
  # avoids version churn when OIDC client_secret rotates underneath us.
  lifecycle {
    ignore_changes = [data]
  }
}
