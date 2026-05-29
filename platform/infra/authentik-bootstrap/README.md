# platform/identity/bootstrap

Provisions the secrets and the PostgreSQL database that Authentik needs to come up on first boot. Pair with `platform/identity/terraform/` (which configures the running Authentik via API) and the `authentik-server` Ansible role (which installs the container).

The module exists as a separate root-level dependency because `platform/identity/terraform/` uses the `goauthentik/authentik` provider — and that provider can't function until Authentik itself is running. Splitting the bootstrap into its own module lets `deploy.sh` apply it in an early `-target=` phase before Authentik exists.

## What it provisions

- **`authentik` PostgreSQL database** in your managed Postgres instance, via [`modules/infrastructure/storage/postgres_database`](../../../modules/infrastructure/storage/postgres_database). The connection details land in a Scaleway secret.
- **`<org>-<env>-authentik-admin` secret** — JSON `{username, email, password, api_token}`. The password is consumed via `AUTHENTIK_BOOTSTRAP_PASSWORD` and the token via `AUTHENTIK_BOOTSTRAP_TOKEN`; Authentik creates both atomically on first boot.
- **`<org>-<env>-authentik-server` secret** — JSON `{secret_key}` for cookie signing and internal crypto.

The admin secret is created with `lifecycle.ignore_changes = [data]`, so the token is pinned for the lifetime of the deployment — re-applies don't churn it.

## Usage

```hcl
module "identity_bootstrap" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/identity/bootstrap?ref=vX.Y.Z"

  org_slug    = var.org_slug
  environment = var.environment
  infra_email = var.infra_email

  postgres_instance_id = module.base.scaleway.postgres_instance_id
  postgres_endpoint    = module.base.scaleway.postgres_endpoint
  postgres_engine      = module.base.scaleway.postgres_engine

  # Optional: pin the Authentik image tag. Empty (default) defers to the
  # authentik-server role's pinned default. Authentik has breaking
  # inter-release DB migrations — set deliberately.
  # authentik_version = "2025.12.1"
}
```

Then in your `deploy.sh`:

```bash
# Phase 1: stand up the bootstrap secrets + database, nothing else.
terraform apply \
  -target=module.base \
  -target=module.identity_bootstrap \
  -auto-approve

# Phase 2: Ansible installs Authentik server. The role reads identity_bootstrap.*
ANSIBLE_EXTRA_VARS="identity_bootstrap=$(terraform output -json identity_bootstrap)"
ansible-playbook bootstrap.yml -e "$ANSIBLE_EXTRA_VARS"

# Phase 3: fetch the token Authentik just created and feed it to the provider.
ADMIN_TOKEN=$(scw secret version access \
  secret-id=$(terraform output -raw identity_bootstrap | jq -r .admin_secret_id) \
  revision=latest --output json | jq -r '.data | @base64d | fromjson | .api_token')

TF_VAR_authentik_admin_token="$ADMIN_TOKEN" terraform apply -auto-approve
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
