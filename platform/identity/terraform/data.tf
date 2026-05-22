# Scaleway secret lookups. Each social-login secret is gated by its enable
# toggle so a consumer that doesn't use Google/Apple doesn't need the secret
# to exist at all. SMTP is optional too: when var.smtp_secret_name is empty
# the lookup is skipped and the email stages are wired in a disabled state
# (use_global_settings = true with null host/port). The flows still exist so
# the rest of the identity bundle plans cleanly; consumers add SMTP later by
# setting smtp_secret_name and re-applying.

# ── SMTP (optional) ─────────────────────────────────────────────────────────

data "scaleway_secret" "smtp_config" {
  count = var.smtp_secret_name != "" ? 1 : 0
  name  = var.smtp_secret_name
}

data "scaleway_secret_version" "smtp_config" {
  count     = var.smtp_secret_name != "" ? 1 : 0
  secret_id = data.scaleway_secret.smtp_config[0].id
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
  smtp_enabled = var.smtp_secret_name != ""
  smtp_config = local.smtp_enabled ? jsondecode(base64decode(data.scaleway_secret_version.smtp_config[0].data)) : {
    smtp_host     = ""
    smtp_port     = 587
    smtp_username = ""
    smtp_password = ""
  }

  google_oauth = var.enable_google_social_login ? jsondecode(base64decode(data.scaleway_secret_version.social_logins_google[0].data)) : { client_id = "", client_secret = "" }
  apple_oauth  = var.enable_apple_social_login ? jsondecode(base64decode(data.scaleway_secret_version.social_logins_apple[0].data)) : { client_id = "", client_secret = "" }
}
