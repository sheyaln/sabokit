# ── OIDC Client Credentials Generation ───────────────────────────────────────

resource "random_uuid" "oidc_client_id" {
  count = var.credentials_preserve ? 0 : 1
}

# Alphanumeric only to avoid shell/env escaping issues (e.g. $ in docker-compose)
resource "random_password" "oidc_client_secret" {
  count   = var.credentials_preserve ? 0 : 1
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

# Read the live secret bag during in-place cutover so we can wire the existing
# client_id + client_secret through `local.*` instead of fresh random values.
data "scaleway_secret" "preserved" {
  count = var.credentials_preserve ? 1 : 0
  name  = "authentik-app-${var.application_slug}"
}

data "scaleway_secret_version" "preserved" {
  count     = var.credentials_preserve ? 1 : 0
  secret_id = data.scaleway_secret.preserved[0].id
  revision  = "latest"
}

resource "scaleway_secret_version" "oidc_credentials" {
  secret_id = scaleway_secret.app_secret.id
  data = jsonencode({
    provider_type = "oidc"

    client_id     = local.client_id
    client_secret = local.client_secret

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
  _preserved    = var.credentials_preserve ? jsondecode(base64decode(data.scaleway_secret_version.preserved[0].data)) : {}
  client_id     = var.credentials_preserve ? local._preserved.client_id : random_uuid.oidc_client_id[0].result
  client_secret = var.credentials_preserve ? local._preserved.client_secret : random_password.oidc_client_secret[0].result
}
