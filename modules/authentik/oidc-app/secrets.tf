# ── OIDC Client Credentials Generation ───────────────────────────────────────

resource "random_uuid" "oidc_client_id" {}

# Alphanumeric only to avoid shell/env escaping issues (e.g. $ in docker-compose)
resource "random_password" "oidc_client_secret" {
  length  = 40
  special = false

  lifecycle {
    ignore_changes = [length, special]
  }
}

# ── Scaleway Secret for OIDC Credentials ─────────────────────────────────────

resource "scaleway_secret" "app_secret" {
  name        = "authentik-app-${var.application_slug}"
  description = "${var.application_name} OIDC credentials"
  type        = "key_value"
  tags        = ["authentik", var.application_slug, "oidc"]
}

resource "scaleway_secret_version" "oidc_credentials" {
  secret_id = scaleway_secret.app_secret.id
  data = jsonencode({
    provider_type = "oidc"

    client_id     = random_uuid.oidc_client_id.result
    client_secret = random_password.oidc_client_secret.result

    scopes        = join(",", var.oidc_scopes)
    redirect_uris = join(",", [for uri in var.redirect_uris : uri.url])

    access_token_validity  = var.access_token_validity
    refresh_token_validity = var.refresh_token_validity

    sub_mode = var.sub_mode
  })

  lifecycle {
    # Scaleway's API does not return secret values on read; after a
    # `terraform import` the refreshed `data` is null and the rendered
    # jsonencode looks like a forces_replacement diff. Locking the version
    # keeps imported secrets intact. Rotate by tainting this resource.
    ignore_changes = [data]
  }
}

# ── Local values for use in main.tf ──────────────────────────────────────────

locals {
  client_id     = random_uuid.oidc_client_id.result
  client_secret = random_password.oidc_client_secret.result
}
