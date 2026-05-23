# apps/decidim

Decidim — Rails-based participatory democracy platform. Self-contained bundle:

- Authentik OIDC provider + application + per-app group (consumed via Decidim's `decidim-omniauth-oauth2` plugin)
- DNS A record on the consumer's base domain
- S3 bucket + IAM credentials for uploads (Active Storage backend)
- PostgreSQL database + user inside `platform/base/terraform/`'s shared instance
- Scaleway-managed secrets bag (`SECRET_KEY_BASE`, system + organization admin passwords, OIDC creds, S3 keys, SMTP from-address)
- Ansible role that deploys app + sidekiq + redis + one-shot db-init as a docker-compose stack with Traefik routing

## Usage

```hcl
module "decidim" {
  source             = "git::https://github.com/sheyaln/sabokit.git//platform/apps/decidim/terraform?ref=v2.2.0"
  enabled            = try(var.apps.decidim.enabled, false)
  hostname           = try(var.apps.decidim.hostname, "")
  base               = module.base
  organization_name  = "Example Assembly"
  system_admin_email = "ops@example.org"
}
```

In `terraform.tfvars`:

```hcl
apps = {
  decidim = {
    enabled  = true
    hostname = "participate.example.org"
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/decidim/ansible/playbook.yml
  vars:
    decidim_host_group: apps
    decidim_hostname: "participate.example.org"
    decidim_app_secret_id: "{{ decidim_terraform_outputs.ansible.vars.decidim_app_secret_id }}"
    decidim_db_credentials_secret_id: "{{ decidim_terraform_outputs.ansible.vars.decidim_db_credentials_secret_id }}"
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. When false the bundle provisions zero resources. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname Decidim is served at. |
| `category_group` | `string` | `"Participation"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | If true and a monitoring app is enabled, log paths wire in. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` identifying the deploy target. |
| `image` | `string` | `"ghcr.io/decidim/decidim"` | Docker image (without tag). |
| `image_tag` | `string` | `"latest"` | Docker image tag. Pin to a release tag for production. |
| `organization_name` | `string` | — (required when enabled) | Display name of the participatory democracy organization. Used to bootstrap the first Decidim organization. |
| `organization_reference_prefix` | `string` | `""` (auto from name) | Short uppercase prefix Decidim stamps on internal reference numbers. |
| `default_locale` | `string` | `"en"` | Two-letter ISO 639-1 locale Decidim defaults to. |
| `available_locales` | `list(string)` | `["en"]` | Locales Decidim makes available in the UI. |
| `system_admin_email` | `string` | — (required when enabled) | Email of the initial `/system` superuser. |
| `organization_admin_email` | `string` | `""` (falls back to `system_admin_email`) | Email of the first organization admin (separate from the `/system` user). |
| `smtp_from_email` | `string` | `""` | From: address for outbound mail. Empty disables SMTP. |
| `max_upload_size_bytes` | `number` | `26214400` | Max upload size (25 MiB default). |
| `storage_bucket_acl` | `string` | `"public-read"` | ACL for the uploads bucket. |
| `sidekiq_concurrency` | `number` | `5` | Sidekiq worker thread count. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID (not bound to outpost — Decidim is OIDC). |
| `authentik_application_group_id` | Per-app group `app-decidim`. |
| `monitoring` | Contribution map for the monitoring aggregation. |
| `ansible` | `{role_path, playbook, host_group, vars}` consumed by site.yml. |
| `uploads_bucket_name` | Convenience: the S3 bucket name. |
| `database_name` | Convenience: the PostgreSQL database name. |
| `system_admin_email` | Echoed back for documentation; password lives in the secrets bag. |

## What lands on the host

After `terraform apply && ansible-playbook site.yml`:

- `/opt/decidim/docker-compose.yml` — managed file (mode 0644)
- `/opt/decidim/.env` — managed file (mode 0600, plaintext secrets re-fetched from Scaleway Secret Manager on every play)
- Four Docker volumes: `decidim_uploads-data`, `decidim_logs-data`, `decidim_redis-data`, `decidim_init-marker`
- Containers: `decidim-app` (web, port 3000), `decidim-sidekiq` (background queues), `decidim-redis` (cache + sidekiq queue store), and a transient `decidim-db-init` (one-shot bootstrap)
- Traefik routes the configured hostname to `decidim-app`

The `db-init` container is the canonical first-boot bootstrapper: it creates the database, runs migrations, seeds, creates the `/system` superuser, and creates the first organization plus its admin. Idempotent via the `init-marker` volume — set `-e decidim_force_db_init=true` to reset and rerun on a wiped database.

## Notes

- OIDC redirect URI is `https://<hostname>/users/auth/oauth2_authentik/callback` (the `decidim-omniauth-oauth2` plugin's convention).
- `SECRET_KEY_BASE` is generated once and pinned via `lifecycle { ignore_changes = all }`. Rotating it invalidates every existing session and breaks every encrypted attribute Decidim has stored — taint deliberately and only when you accept that blast radius.
- The shipped Decidim image (`ghcr.io/decidim/decidim`) precompiles assets at image-build time, so there is no in-role `assets:precompile` step. If you build your own image (custom modules, branding), make sure your Dockerfile runs `bundle exec rails assets:precompile` before publishing.
- After a Decidim version bump, the role runs `rails db:migrate` defensively on each play — it's a no-op when no migrations are pending.

## Disabling

Set `apps.decidim.enabled = false` in tfvars and `terraform apply`. Terraform destroys the Authentik resources, the DNS record, the S3 bucket, the database (⚠ data loss), and the Scaleway secrets. The compose stack on the host is **not** auto-torn-down — `ssh apps && cd /opt/decidim && docker compose down -v && sudo rm -rf /opt/decidim` to fully remove.
