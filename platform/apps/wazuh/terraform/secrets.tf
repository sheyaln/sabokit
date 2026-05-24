# Wazuh internal-user passwords (indexer admin, manager API, dashboard).
# Pinned: the opensearch-security bootstrap embeds bcrypt hashes of these
# into the security index on first start. Rotating requires running
# wazuh-passwords-tool inside the manager.

resource "random_password" "indexer_admin" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "api" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "dashboard" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "scaleway_secret" "app" {
  count       = var.enabled ? 1 : 0
  name        = "${local.slug}-app-secrets"
  description = "Wazuh internal-user passwords (indexer admin, API, dashboard)"
  tags        = ["automated", local.slug]
  type        = "key_value"
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    WAZUH_INDEXER_PASSWORD   = random_password.indexer_admin[0].result
    WAZUH_API_PASSWORD       = random_password.api[0].result
    WAZUH_DASHBOARD_PASSWORD = random_password.dashboard[0].result
    OIDC_CLIENT_ID           = module.authentik[0].client_id
    OIDC_CLIENT_SECRET       = module.authentik[0].client_secret
    OIDC_DISCOVERY_URL       = local.oidc_discovery_url
    OIDC_BASE_REDIRECT_URL   = local.app_url
  })

  lifecycle {
    # These bootstrap the security index on first deploy. Rotating after
    # that requires `/var/ossec/api/scripts/wazuh-passwords-tool.sh` from
    # inside the manager container — don't churn the secret version.
    ignore_changes = all
  }
}
