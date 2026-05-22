# authentik-server

Installs and runs a self-hosted Authentik (server + worker) as a docker-compose stack. Pairs with `platform/identity/terraform/` which then configures flows, brand, sources, groups, and the embedded outpost via the Authentik API.

## Run order

1. `platform/base/ansible/roles/traefik` must have run on the host first (the Authentik container attaches to the `traefik` Docker network and emits routing labels).
2. The Scaleway Postgres `authentik` database must exist (provisioned via terraform — either base postgres + a per-app `postgres_database` module call, or pre-existing).
3. The Scaleway secrets enumerated below must be populated before this role runs.

## Required variables

| Variable | Source |
|----------|--------|
| `authentik_hostname` | Full hostname Authentik is served at (`auth.example.org`). |
| `authentik_postgres_secret_id` | Scaleway secret ID. Payload: `{host, port, dbname, username, password}`. |
| `authentik_admin_secret_id` | Scaleway secret ID. Payload: `{username, email, password, api_token}`. The bootstrap admin user is created from password+email on first boot, and the api_token field becomes the AUTHENTIK_BOOTSTRAP_TOKEN — Authentik creates a Token row with that key, which is what the Terraform `authentik` provider then authenticates with. See `platform/identity/bootstrap/`. |
| `authentik_server_secret_id` | Scaleway secret ID. Payload: `{secret_key}` (32+ random bytes). |

## Optional variables

| Variable | Default | Description |
|----------|---------|-------------|
| `authentik_legacy_hostname` | `""` | Second hostname Traefik also routes to Authentik. Useful during migrations. |
| `authentik_image` | `ghcr.io/goauthentik/server` | |
| `authentik_version` | `2025.12.1` | |
| `authentik_dir` | `/opt/authentik` | Install path on disk. |
| `authentik_traefik_docker_network` | `traefik` | External Docker network the container joins. |
| `authentik_traefik_cert_resolver` | `le` | Name of the Traefik cert resolver (matches `traefik_acme_*` config). |
| `authentik_media_s3_secret_id` | `""` | Scaleway secret with `{access_key, secret_key, bucket_name, region, endpoint, custom_domain}` for S3-backed media. Empty = local volume. |
| `authentik_smtp_secret_id` | `""` | Scaleway secret with `{host, port, username, password, use_tls, use_ssl, from}`. Empty = SMTP disabled. |
| `authentik_metrics_bind_ip` | `""` (= `0.0.0.0`) | Private IP for the metrics port. |
| Resource limits | see `defaults/main.yml` | Server and worker memory/CPU bounds. |

## What it provisions

- `/opt/authentik/{data, data/media, custom-templates, certs}` directories
- `/opt/authentik/docker-compose.yml` (rendered)
- `/opt/authentik/.env` (rendered, mode 0600)
- Docker network `authentik-internal`
- Compose project: `server` (port 127.0.0.1:9000, plus 9300 for metrics on private IP) and `worker`
- Waits for `GET /api/v3/root/config/` to return 200 before exiting

## Bootstrap admin token

The role wires `AUTHENTIK_BOOTSTRAP_TOKEN` from the `api_token` field of the admin secret. Authentik's first-boot migration creates a Token row whose `key` equals that env var's value — so by the time the role's "wait for healthy" loop exits, the token already exists and matches what was stored in Terraform state.

`deploy.sh` reads the same `api_token` field from the admin secret and exports it as `TF_VAR_authentik_admin_token` before the second-phase `terraform apply` that drives the `authentik` provider. The provider authenticates with the same value Authentik just minted — no out-of-band mint, no `ak shell`, no `POST /api/v3/core/tokens/`.

Re-applies are a no-op: Terraform pins the token via `lifecycle.ignore_changes = [data]` on the admin secret version, and Authentik treats the env var as a no-op once a Token with that key exists.

## When NOT to use

If you bring your own IdP (external Keycloak, Okta, Azure AD), skip this role. Drop `platform/identity/` from your `consumer-template/modules/stack/identity.tf` and provide your own `local.base.authentik = { ... }` map matching the contract documented in `ARCHITECTURE.md`.
