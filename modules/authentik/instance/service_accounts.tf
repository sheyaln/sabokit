
# =============================================================================
# SERVICE ACCOUNTS
# =============================================================================
# Machine identities for automated processes that need Authentik SSO access.
# Each account is assigned to per-app groups (app-{slug}) created by the
# oidc-app module, which are already policy-bound to their applications.
# This grants minimal app-specific access without touching user-facing groups.
# =============================================================================


# ── n8n Service Account ───────────────────────────────────────────────────────
# Machine identity used by n8n to authenticate against Nextcloud and call the
# Forms API (e.g. Nextcloud Form Edit-Access Email Notifier workflow).
#
# After apply, complete setup:
#   1. Log into cloud.${var.domain} as svc-n8n using the password
#      stored in Scaleway secret "authentik-svc-n8n".
#   2. Go to Settings → Security → App Passwords.
#   3. Create an app password (label: "n8n automation").
#   4. Create an HTTP Basic Auth credential in n8n named "Nextcloud account"
#      with username "svc-n8n@<tools_domain>" and the app password (not the
#      account password). This credential is used by the Nextcloud HTTP nodes.
# ─────────────────────────────────────────────────────────────────────────────

resource "random_password" "n8n_service" {
  length  = 32
  special = false # Alphanumeric only — avoids shell/env escaping issues

  lifecycle {
    ignore_changes = [length, special]
  }
}

resource "authentik_user" "n8n_service" {
  username  = "svc-n8n@${var.domain}"
  name      = "n8n Service Account"
  email     = "svc-n8n@${var.domain}"
  password  = random_password.n8n_service.result
  type      = "service_account"
  is_active = true

  # Per-app groups are always policy-bound to their application (oidc-app/main.tf:199).
  # Assigning here grants access to exactly these two apps and nothing else.
  # union-automation is synced to Nextcloud on login (union- prefix convention);
  # share Nextcloud Forms with this group to grant svc-n8n read/edit access.
  groups = [
    module.n8n.application_group_id,       # app-n8n
    module.nextcloud.application_group_id, # app-cloud
    authentik_group.union_automation.id,   # union-automation → synced to Nextcloud
    authentik_group.union_cloud_admin.id,  # union-cloud-admin → Nextcloud admin via group sync
  ]
  attributes = jsonencode({
    # Prevents activation notification emails for service accounts.
    activation_notification_sent = true
  })
  lifecycle {
    # Authentik stores a hash; Terraform cannot detect password drift.
    # To rotate: taint random_password.n8n_service, then re-apply and update
    # the Nextcloud app password in Nextcloud settings.
    ignore_changes = [password]
  }
}

# ── Scaleway Secret ───────────────────────────────────────────────────────────
# Stores the account password. The Nextcloud app password (created post-apply)
# is separate and managed outside Terraform.

resource "scaleway_secret" "n8n_service_account" {
  name        = "authentik-svc-n8n"
  description = "Authentik service account credentials for n8n automation"
  type        = "key_value"
  tags        = ["authentik", "service-account", "n8n"]
}

resource "scaleway_secret_version" "n8n_service_account" {
  secret_id = scaleway_secret.n8n_service_account.id
  data = jsonencode({
    username = authentik_user.n8n_service.username
    email    = authentik_user.n8n_service.email
    password = random_password.n8n_service.result
  })
}
