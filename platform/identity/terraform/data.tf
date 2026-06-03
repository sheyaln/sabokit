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

  # Schema matches what `platform/base/terraform/tem.tf` writes into the
  # smtp-config secret bag: host / port / username / password (plus optional
  # use_tls / domain / from_email which identity doesn't consume).
  # Disabled-shape mirrors the same keys (empty strings, port=587) so the
  # downstream interpolation evaluates without conditional null-handling
  # at every reference site.
  smtp_config_raw = local.smtp_enabled ? jsondecode(base64decode(data.scaleway_secret_version.smtp_config[0].data)) : {
    host     = ""
    port     = "587"
    username = ""
    password = ""
  }
  smtp_config = {
    smtp_host     = local.smtp_config_raw.host
    smtp_port     = tonumber(local.smtp_config_raw.port)
    smtp_username = local.smtp_config_raw.username
    smtp_password = local.smtp_config_raw.password
  }

  google_oauth = var.enable_google_social_login ? jsondecode(base64decode(data.scaleway_secret_version.social_logins_google[0].data)) : { client_id = "", client_secret = "" }
  apple_oauth  = var.enable_apple_social_login ? jsondecode(base64decode(data.scaleway_secret_version.social_logins_apple[0].data)) : { client_id = "", client_secret = "" }
}
