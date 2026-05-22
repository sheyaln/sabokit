# platform/identity/bootstrap — pre-Authentik secret + database provisioning.
#
# platform/identity/terraform/ configures Authentik via the goauthentik/authentik
# provider, which can only function once Authentik itself is running and has an
# API token. This module provisions the three things Authentik needs to BE
# running:
#
#   1. A per-app PostgreSQL database (via postgres_database)
#   2. A bootstrap admin user — password + a pre-generated API token, stored
#      together in a key_value secret. Authentik reads BOOTSTRAP_PASSWORD on
#      first boot to create the admin user, and BOOTSTRAP_TOKEN to create the
#      matching API Token in one shot. No post-install "mint a token" step is
#      needed; the value the role wires into the env IS the value the Terraform
#      authentik provider authenticates with.
#   3. A server-side secret_key for cookie signing.
#
# Apply order with the rest of the stack:
#
#   Phase 1: terraform apply -target=module.<base> \
#                            -target=module.<identity_bootstrap>
#            → secrets exist, postgres has the authentik DB
#   Phase 2: ansible-playbook bootstrap.yml
#            → authentik-server role renders env (including BOOTSTRAP_TOKEN),
#              compose up; Authentik creates admin + token on first boot.
#   Phase 3: terraform apply (full)
#            → identity module hits the running Authentik with the same token,
#              configures flows / brand / groups / outpost.
#
# Re-applies are idempotent: random_password has lifecycle ignore_changes, the
# secret_version is locked once written, and AUTHENTIK_BOOTSTRAP_TOKEN is a
# no-op on subsequent boots (the Token row already exists).

locals {
  secret_tags = distinct(concat(["authentik", "identity", var.environment], var.tags))
  secret_name_prefix = "${var.org_slug}-${var.environment}-authentik"
}

# ── PostgreSQL database ─────────────────────────────────────────────────────

module "database" {
  source = "../../../modules/infrastructure/storage/postgres_database"

  instance_id       = var.postgres_instance_id
  instance_endpoint = var.postgres_endpoint
  database_name     = "authentik"
  engine            = var.postgres_engine
  tags              = local.secret_tags
}

# ── Bootstrap admin password ────────────────────────────────────────────────
# Authentik reads AUTHENTIK_BOOTSTRAP_PASSWORD on first boot only. Rotating
# this after deployment requires a manual password change in the Authentik UI.

resource "random_password" "admin" {
  length  = 32
  special = false

  lifecycle {
    ignore_changes = [length, special]
  }
}

# ── Bootstrap admin API token ───────────────────────────────────────────────
# Authentik reads AUTHENTIK_BOOTSTRAP_TOKEN on first boot and creates a Token
# resource attached to the bootstrap admin user with key=this value. On
# subsequent boots the env var is ignored (Token already exists with that key).
# The Terraform authentik provider then authenticates with this same value.

resource "random_password" "admin_api_token" {
  length  = 60
  special = false

  lifecycle {
    ignore_changes = [length, special]
  }
}

resource "scaleway_secret" "admin" {
  name        = "${local.secret_name_prefix}-admin"
  description = "Authentik bootstrap admin credentials + AUTHENTIK_BOOTSTRAP_TOKEN. Read by the authentik-server Ansible role to render .env."
  type        = "key_value"
  tags        = local.secret_tags
}

resource "scaleway_secret_version" "admin" {
  secret_id = scaleway_secret.admin.id
  data = jsonencode({
    username  = var.admin_username
    email     = var.infra_email
    password  = random_password.admin.result
    api_token = random_password.admin_api_token.result
  })

  lifecycle {
    # Token + password are immutable for the lifetime of the deployment.
    # If you genuinely need to rotate, taint random_password.admin_api_token
    # (or .admin), re-apply, then update Authentik's User/Token rows manually.
    ignore_changes = [data]
  }
}

# ── Server-side secret_key ──────────────────────────────────────────────────
# Used by Authentik for cookie signing and internal crypto. Rotating this
# invalidates all sessions and any encrypted-at-rest blobs (uncommon — most
# state is in Postgres which doesn't use AUTHENTIK_SECRET_KEY).

resource "random_id" "server_key" {
  byte_length = 32
}

resource "scaleway_secret" "server" {
  name        = "${local.secret_name_prefix}-server"
  description = "Authentik server-side secret_key (cookie signing, internal crypto)."
  type        = "key_value"
  tags        = local.secret_tags
}

resource "scaleway_secret_version" "server" {
  secret_id = scaleway_secret.server.id
  data = jsonencode({
    secret_key = random_id.server_key.hex
  })

  lifecycle {
    ignore_changes = [data]
  }
}
