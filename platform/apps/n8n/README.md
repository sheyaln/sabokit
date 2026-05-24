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

## Usage

```hcl
module "n8n" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/n8n/terraform?ref=v2.3.0"
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
- Docker named volume `n8n_data` for `/home/node/.n8n` (encryption key on disk, queue, etc.)
- Containers `n8n` (port 5678) and `n8n-runners` on a project-scoped internal network

## Disabling

Set `apps.n8n.enabled = false` in tfvars and `terraform apply`. Drops the Authentik resources, the DNS record, the database (⚠ data loss — all workflows and credentials gone), and the Scaleway secret. The compose stack and the `/opt/n8n/` directory on the host are not auto-torn-down — `ssh apps && cd /opt/n8n && docker compose down -v && sudo rm -rf /opt/n8n` to fully remove.

## Bundled workflows

`ansible/roles/n8n/files/workflows/` ships JSON exports that pair with `platform/identity/`'s notification webhook. They are **not auto-imported** — import once from the n8n UI (`Workflows → Import from File`).

| File | Purpose |
|------|---------|
| `authentik-user-onboarding.json` | Dispatcher webhook. Receives `user_signup` and `user_activation` events from the Authentik notification policies; posts the signup notice to Slack and (on activation) fans out to the two sub-workflows below. |
| `authentik-user-lifecycle-notifier.json` | Receives full Authentik user-lifecycle webhook events (created / activated / deactivated / deleted) and posts a richly-formatted Slack card to `#user-onboarding`. Sister workflow to onboarding; covers the post-signup states. |
| `espocrm-member-upsert.json` | Sub-workflow. Looks up a CRM `Member` by email; creates one if missing, otherwise updates a small set of fields while preserving everything else. Refuses to act on duplicate matches and alerts an admin channel. |
| `espocrm-membership-notifier.json` | Posts to `#membership-events` when an EspoCRM Member's `membershipStatus` changes (good standing / in arrears / suspended / etc.). Useful as a Slack feed for membership coordinators. |
| `slack-invite-stub.json` | Sub-workflow. No-op placeholder for Slack workspace provisioning — Slack Free has no usable invite API. Replace the Code node when a real path exists. |
| `error-notification.json` | Global error trigger. When any other workflow throws, a richly-formatted error card lands in `#infra-alerts` with workflow name, execution ID, last node, error message, stacktrace, and an "Open Workflow" link. Point this workflow's ID at every other workflow's `Workflow settings → Error Workflow`. |
| `infra-notifications-receiver.json` | Generic webhook receiver on `/webhook/infra-notifications`. Formats incoming JSON (unattended-upgrade events, etc.) into Slack Block Kit cards posted to `#infra-alerts`. Use as the target for Ansible/cron/SSH callbacks that need a human-readable feed. |
| `scaleway-billing-forecast.json` | Daily scheduled run: pulls Scaleway billing data, computes month-end forecast, and posts to `#infra-alerts` when the projection crosses thresholds. Pair with a `Scaleway` HTTP-header credential. |
| `tem-delivery-alerting.json` | **Deprecated as of v2.9.0** — TEM observability now flows through Grafana (dashboard + alert rules in the prometheus bundle's `monitoring/`) → `grafana-alert-router.json`. This workflow still works as a TEM SNS-webhook receiver if you want per-event alerts in addition to the dashboard. New deployments should prefer the Grafana path. |
| `grafana-alert-router.json` | Generic Grafana alert webhook receiver on `/webhook/grafana-alerts`. Parses Grafana's standard alert webhook payload (`alerts[]` with labels/annotations/status/severity), fans out by `labels.severity` (`critical` / `warning` / `info`) to Slack + email. Point Grafana's webhook contact point at `https://<n8n hostname>/webhook/grafana-alerts`. Required env: `SLACK_WEBHOOK_INFRA_ALERTS` (warning + info), optional `SLACK_WEBHOOK_INFRA_CRITICAL` (falls back to the alerts webhook), `INFRA_EMAIL` + `SMTP_FROM` for the critical email path. |
| `nextcloud-form-submission-notifier.json` | Receives `OCA\Forms\Events\FormSubmittedEvent` webhooks from Nextcloud (registered automatically when the `nextcloud` bundle's `n8n_form_webhook_url` points here). Fetches form schema + recent submissions via the Nextcloud OCS API, formats as email, and sends to form editors. Pair with a `Nextcloud admin` HTTP basic-auth credential + SMTP. |
| `nextcloud-form-edit-access-notifier.json` | Sister workflow: when a form's edit-access list changes, notifies the newly-added editor(s) by email. Same credentials as above. |
| `jotform-submission-notifier.json` | Generic Jotform → Slack notifier. Before activating, set the form ID in the `Jotform Trigger` node (replace `REPLACE_WITH_JOTFORM_FORM_ID`) and the channel in the `Post to Slack` node (default `#form-submissions`). Walks the entire submission payload — no per-form field mapping needed. Pair with a `JotForm account` API credential. |

All workflows ship as `"active": false` — review and activate manually after import. Credential IDs and `instanceId` fields are scrubbed from the JSON so n8n won't try to bind to credentials from another instance. Re-bind credentials and (in dispatcher workflows) the `Execute Workflow` node targets via the n8n UI; n8n cannot resolve those across instances.

**Required n8n credentials** (create in `Credentials → New`, named exactly as below):

| Name | Type | Used by | Notes |
|------|------|---------|-------|
| `Slack account` | Slack API (Bot token, `xoxb-…`) | every notifier | Bot scopes: `chat:write`, `channels:read`. |
| `EspoCRM API` | HTTP Header Auth | EspoCRM workflows | Header `X-Api-Key`, value from a CRM API User. `allowedDomains` must include the CRM base URL. |
| `Scaleway` | HTTP Header Auth | billing-forecast, tem-delivery | Header `X-Auth-Token`, value = a Scaleway API key with billing + TEM read scopes. |
| `Nextcloud admin` | HTTP Basic Auth | nextcloud form notifiers | Admin username + password from `terraform output`. |
| `SMTP` | SMTP | nextcloud form notifiers, anything sending email | Same SMTP creds shared across platform. |
| `JotForm account` | JotForm API | jotform-submission-notifier | API key from your JotForm account's `Settings → API`. |

**Required n8n environment variables** (set in `platform/apps/n8n/ansible/.../docker-compose` env or the host's `/opt/n8n/.env`):

| Variable | Used by | Example |
|----------|---------|---------|
| `ESPOCRM_BASE_URL` | EspoCRM upsert | `https://crm.example.org` |
| `SLACK_CHANNEL_NEW_SIGNUPS` | Dispatcher | `#new-signups` |
| `SLACK_CHANNEL_ADMIN_ALERTS` | EspoCRM upsert (duplicate alert) | `#ops-alerts` |

Point Authentik at the dispatcher: set `notification_webhook_url` in the identity stack to `https://<n8n hostname>/webhook/authentik-user-onboarding`.

## Notes

- OIDC redirect URI is `https://<hostname>/auth/oidc/callback` (the path served by hooks.js).
- The runners sidecar image (`n8nio/runners`) MUST be the same tag as n8n itself — upstream requirement. `image_tag` is reused for both.
- Python imports in workflows: the upstream `n8n-task-runners.json` defaults to an empty allowlist that blocks even `import json`. The shipped template opens a common-safe stdlib set; tune with `python_stdlib_allow` / `python_external_allow`.
- n8n's metrics endpoint (`/metrics`) is off by default — set `n8n_metrics_enabled = true` on the role side and add a scrape config in `monitoring.tf` to surface workflow execution metrics.
