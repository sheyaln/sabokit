# Wazuh internal-user passwords (indexer admin, manager API, dashboard).
# Pinned: the opensearch-security bootstrap embeds bcrypt hashes of these
# into the security index on first start. Rotating requires running
# wazuh-passwords-tool inside the manager.

resource "random_password" "indexer_admin" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false

  lifecycle {
    # Required for `terraform import`: imported state has null length/special
    # which would otherwise conflict and trigger force-replacement.
    ignore_changes = all
  }
}

resource "random_password" "api" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "random_password" "dashboard" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false

  lifecycle {
    ignore_changes = all
  }
}

# Agent enrollment (authd) password. The manager requires it on the 1515
# enrollment port (use_password=yes); every agent presents it to register.
# Without it, enrollment is open to anyone who can reach 1515.
resource "random_password" "authd" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "scaleway_secret" "app" {
  count       = var.enabled ? 1 : 0
  name        = "${local.slug}-app-secrets"
  description = "Wazuh internal-user passwords (indexer admin, API, dashboard, agent enrollment)"
  tags        = ["automated", local.slug]
  type        = "key_value"
}

locals {
  indexer_password   = var.enabled ? (random_password.indexer_admin[0].result) : ""
  api_password       = var.enabled ? (random_password.api[0].result) : ""
  dashboard_password = var.enabled ? (random_password.dashboard[0].result) : ""
  authd_password     = var.enabled ? (random_password.authd[0].result) : ""
  app_secret_id      = var.enabled ? (scaleway_secret.app[0].id) : ""
}

resource "scaleway_secret_version" "app" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.app[0].id
  data = jsonencode({
    WAZUH_INDEXER_PASSWORD   = local.indexer_password
    WAZUH_API_PASSWORD       = local.api_password
    WAZUH_DASHBOARD_PASSWORD = local.dashboard_password
    WAZUH_AUTHD_PASSWORD     = local.authd_password
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
