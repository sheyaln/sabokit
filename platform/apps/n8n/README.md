# apps/n8n

n8n — open-source workflow automation. Self-contained bundle:

- Authentik OIDC provider + application + per-app group (defaults to admin-only access; n8n holds credentials for every connected system)
- DNS A record on the consumer's base domain
- PostgreSQL database + user in the shared instance from `platform/base/`
- Scaleway-managed secrets bag (`N8N_ENCRYPTION_KEY`, runners auth token, OIDC bag)
- Ansible role that deploys n8n + the `n8nio/runners` Python+JS sidecar as a single docker-compose stack
- Traefik routing with a separate, rate-limited router for the public webhook paths

## Critical lifecycle notes

- **`N8N_ENCRYPTION_KEY` is immutable.** It encrypts every credential in n8n's database (every Slack token, every OAuth refresh token, every API key). Rotating it bricks the entire credential store. The Terraform `random_password.encryption_key` has `lifecycle { ignore_changes = all }` so re-applies don't regenerate it. To genuinely rotate, taint it AND plan to re-enter every credential from the UI.
- **`N8N_RUNNERS_AUTH_TOKEN` is also locked** — same treatment. Rotating mid-run kills any in-flight workflow.
- **`scaleway_secret_version.app` has `ignore_changes = [data]`** so peripheral fields (e.g. OIDC client_secret rotating underneath) don't churn the version forever. To force a re-render, taint it.

## Build-from-source vs upstream image

Default: pull `docker.n8n.io/n8nio/n8n:<tag>` and bind-mount `hooks.js` into the container. Fast, no build step, no local image cache to manage.

Flip `build_from_source = true` to render a local `Dockerfile` that layers `python3 + pip` on top of the upstream image. Only useful if a workflow's Execute Command node needs to shell out to system python — n8n's Code-node Python execution already happens in the `n8nio/runners` sidecar (which ships with python preinstalled) and works without the custom build.

## Usage

```hcl
module "n8n" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/n8n/terraform?ref=v2.2.0"
  enabled  = try(var.apps.n8n.enabled, false)
  hostname = try(var.apps.n8n.hostname, "")
  base     = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  n8n = {
    enabled  = true
    hostname = "flows.example.org"
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/n8n/ansible/playbook.yml
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname. |
| `category_group` | `string` | `"Automation"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon. |
| `access_level` | `string` | `"admin"` | Defaults to admin-only — n8n is an ops tool. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image_tag` | `string` | `"latest"` | n8n image tag (used for both n8n and the runners sidecar). |
| `build_from_source` | `bool` | `false` | Build a custom image with python3+pip on top of the upstream image. |
| `n8n_admin_group_name` | `string` | `"admin"` | OIDC group whose members become n8n owners. |
| `timezone` | `string` | `"UTC"` | IANA timezone for the container. |
| `public_api_disabled` | `bool` | `true` | Disable n8n's REST API (high-value target). |
| `python_stdlib_allow` | `string` | `"json,re,math,..."` | Comma-list of Python stdlib modules workflows may import. |
| `python_external_allow` | `string` | `""` | Comma-list of third-party Python packages workflows may import. |
| `webhook_rate_limit_average` | `number` | `100` | Traefik average req/period for the webhook router. |
| `webhook_rate_limit_burst` | `number` | `50` | Traefik burst. |
| `webhook_rate_limit_period` | `string` | `"1m"` | Traefik period (Go duration). |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-n8n`. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `database_name` | PostgreSQL database. |

## OIDC and user provisioning

OIDC is handled inside the n8n container by `ansible/roles/n8n/files/hooks.js`. It's loaded via `EXTERNAL_HOOK_FILES` and bind-mounted from the host. The hook:

1. Runs the OIDC authorization-code flow against the issuer URL.
2. JIT-provisions a user record on first login.
3. Assigns n8n's role from the OIDC `groups` claim:
   - **first ever user** always becomes `global:owner` (bootstrap — even if their group isn't in OIDC_ADMIN_GROUP)
   - **subsequent users** in the `n8n_admin_group_name` group become `global:owner`
   - everyone else becomes `global:member`
4. Replaces the password form on `/signin` with an SSO button (admins can still bypass with `?showLogin=true`).

Authentik emits group names as strings in the `groups` claim, which is what the hook checks against.

## Routing

Two Traefik routers on the same hostname:

- `n8n` (priority 10) — editor UI and `/rest/*`. OIDC enforced inside n8n by the hook.
- `n8n-webhooks` (priority 20) — `/webhook/`, `/webhook-test/`, `/form/`, `/mcp-server`. Public, rate-limited.

Webhooks must be public because that's the whole point — external services (Stripe, GitHub, form submitters) call them with no Authentik session. The rate-limit middleware is the only thing standing between an open endpoint and a flood.

## What lands on the host

After `terraform apply && ansible-playbook site.yml`:

- `/opt/n8n/docker-compose.yml` — managed file (mode 0644)
- `/opt/n8n/.env` — managed file (mode 0600, regenerated from Scaleway Secret Manager on every play)
- `/opt/n8n/hooks.js` — OIDC external hook, bind-mounted into the container
- `/opt/n8n/n8n-task-runners.json` — runners launcher config, mounted into the sidecar
- `/opt/n8n/Dockerfile` — only when `build_from_source = true`
- Docker named volume `n8n_data` for `/home/node/.n8n` (encryption key on disk, queue, etc.)
- Containers `n8n` (port 5678) and `n8n-runners` on a project-scoped internal network

## Disabling

Set `apps.n8n.enabled = false` in tfvars and `terraform apply`. Drops the Authentik resources, the DNS record, the database (⚠ data loss — all workflows and credentials gone), and the Scaleway secret. The compose stack and the `/opt/n8n/` directory on the host are not auto-torn-down — `ssh apps && cd /opt/n8n && docker compose down -v && sudo rm -rf /opt/n8n` to fully remove.

## Notes

- OIDC redirect URI is `https://<hostname>/auth/oidc/callback` (the path served by hooks.js).
- The runners sidecar image (`n8nio/runners`) MUST be the same tag as n8n itself — upstream requirement. `image_tag` is reused for both.
- Python imports in workflows: the upstream `n8n-task-runners.json` defaults to an empty allowlist that blocks even `import json`. The shipped template opens a common-safe stdlib set; tune with `python_stdlib_allow` / `python_external_allow`.
- n8n's metrics endpoint (`/metrics`) is off by default — set `n8n_metrics_enabled = true` on the role side and add a scrape config in `monitoring.tf` to surface workflow execution metrics.
