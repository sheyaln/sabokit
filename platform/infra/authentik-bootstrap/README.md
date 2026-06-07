# authentik-bootstrap

Provisions the secrets and the PostgreSQL database that Authentik needs to come up on first boot. Pair with `platform/identity/terraform/` (which configures the running Authentik via API) and the `authentik-server` Ansible role (which installs the container).

It's a submodule of the **infra** layer (the root-of-trust fold): the `goauthentik/authentik` provider the identity layer uses can't function until Authentik is running, so the secrets + DB Authentik boots from must exist first. Composing the bootstrap into infra mints them in the first apply, well before the identity layer's Ansible boots the Authentik container.

## What it provisions

- **`authentik` PostgreSQL database** in your managed Postgres instance, via [`_shared/infrastructure/storage/postgres_database`](../../_shared/infrastructure/storage/postgres_database). The connection details land in a Scaleway secret.
- **`<org>-<env>-authentik-admin` secret** — JSON `{username, email, password, api_token}`. The password is consumed via `AUTHENTIK_BOOTSTRAP_PASSWORD` and the token via `AUTHENTIK_BOOTSTRAP_TOKEN`; Authentik creates both atomically on first boot.
- **`<org>-<env>-authentik-server` secret** — JSON `{secret_key}` for cookie signing and internal crypto.

The admin secret is created with `lifecycle.ignore_changes = [data]`, so the token is pinned for the lifetime of the deployment — re-applies don't churn it.

## Usage

Composed by the infra layer — `platform/infra/terraform/authentik_bootstrap.tf` instantiates it from the layer's own Postgres:

```hcl
module "authentik_bootstrap" {
  source = "../authentik-bootstrap"

  org_slug    = var.org_slug
  environment = var.environment
  infra_email = var.infra_email

  postgres_instance_id = module.postgres[0].instance_id
  postgres_endpoint    = module.postgres[0].endpoint
  postgres_engine      = var.postgres_engine

  # Optional: pin the Authentik image tag. Empty (default) defers to the
  # authentik-server role's pinned default. Authentik has breaking
  # inter-release DB migrations — set deliberately.
  # authentik_version = "2025.12.1"
}
```

The apply rhythm, driven by the per-layer deploy scripts:

```bash
# 1. infra applies — mints these secrets + the authentik DB.
scripts/infra.sh <env>

# 2. identity: ansible boots the Authentik server (the authentik-server role
#    reads `identity_bootstrap`), then terraform configures it. The script
#    fetches api_token from admin_secret_id -> TF_VAR_authentik_admin_token.
scripts/identity.sh <env>
```

## Outputs

| Name | Description |
|------|-------------|
| `identity_bootstrap` | Map `{postgres_secret_id, admin_secret_id, server_secret_id, media_s3_secret_id, smtp_secret_id, authentik_version}` — consumed verbatim by `platform/ansible/bootstrap.yml` via `-e identity_bootstrap=...`. `authentik_version` is the only non-secret field (the pinned image tag; empty defers to the role default). |
| `admin_secret_id` | Admin credentials secret — JSON `{username, email, password, api_token}`. |
| `server_secret_id` | Server `secret_key` secret. |
| `database_secret_id` | PostgreSQL database credentials secret. |

## Why `AUTHENTIK_BOOTSTRAP_TOKEN`, not an `ak shell` post-install step?

Authentik's bootstrap envvars (`AUTHENTIK_BOOTSTRAP_USER`, `_PASSWORD`, `_TOKEN`, `_EMAIL`) are read by the server's first-boot migration code and translate directly into User and Token rows. The token is created with `key=$AUTHENTIK_BOOTSTRAP_TOKEN` — meaning the value we pre-generate here is the value we authenticate with. No second round-trip, no `docker compose exec`, no `POST /api/v3/core/tokens/`.

Re-applies are idempotent because Terraform pins the token (`ignore_changes = [data]`) and Authentik treats the env var as a no-op when the Token row already exists with that key.
