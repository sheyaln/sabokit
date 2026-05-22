# Scaleway secret lookups. Each social-login secret is gated by its enable
# toggle so a consumer that doesn't use Google/Apple doesn't need the secret
# to exist at all. SMTP config is required (Authentik needs it to send the
# password-reset, MFA-reset and invitation emails the flows submodule wires).

# ── SMTP ────────────────────────────────────────────────────────────────────

data "scaleway_secret" "smtp_config" {
  name = var.smtp_secret_name
}

data "scaleway_secret_version" "smtp_config" {
  secret_id = data.scaleway_secret.smtp_config.id
  revision  = "latest"
}

# ── Google social login (opt-in) ────────────────────────────────────────────

data "scaleway_secret" "social_logins_google" {
  count = var.enable_google_social_login ? 1 : 0
  name  = "social-google-oauth-credentials"
}

data "scaleway_secret_version" "social_logins_google" {
  count     = var.enable_google_social_login ? 1 : 0
  secret_id = data.scaleway_secret.social_logins_google[0].id
  revision  = "latest"
}

# ── Apple social login (opt-in) ─────────────────────────────────────────────

data "scaleway_secret" "social_logins_apple" {
  count = var.enable_apple_social_login ? 1 : 0
  name  = "social-apple-oauth-credentials"
}

data "scaleway_secret_version" "social_logins_apple" {
  count     = var.enable_apple_social_login ? 1 : 0
  secret_id = data.scaleway_secret.social_logins_apple[0].id
  revision  = "latest"
}

# ── Decoded secrets ─────────────────────────────────────────────────────────

locals {
  smtp_config = jsondecode(base64decode(data.scaleway_secret_version.smtp_config.data))

  google_oauth = var.enable_google_social_login ? jsondecode(base64decode(data.scaleway_secret_version.social_logins_google[0].data)) : { client_id = "", client_secret = "" }
  apple_oauth  = var.enable_apple_social_login ? jsondecode(base64decode(data.scaleway_secret_version.social_logins_apple[0].data)) : { client_id = "", client_secret = "" }
}
