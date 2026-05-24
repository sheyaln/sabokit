# apps/decidim

Decidim — Rails-based participatory democracy platform. Deploys app + sidekiq + redis as a docker-compose stack with a one-shot `db-init` container that bootstraps the first organization. PostgreSQL is the shared instance; uploads go to S3.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname Decidim is served at. |
| `category_group` | `string` | `"Participation"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image` | `string` | `"ghcr.io/decidim/decidim"` | Docker image (without tag). |
| `image_tag` | `string` | `"latest"` | Docker image tag. Pin to a release for production. |
| `organization_name` | `string` | — (required when enabled) | Display name of the first Decidim organization. |
| `organization_reference_prefix` | `string` | `""` (auto from name) | Short uppercase prefix on internal reference numbers. |
| `default_locale` | `string` | `"en"` | Two-letter ISO 639-1 default locale. |
| `available_locales` | `list(string)` | `["en"]` | Locales exposed in the UI. |
| `system_admin_email` | `string` | — (required when enabled) | Email of the initial `/system` superuser. |
| `organization_admin_email` | `string` | `""` (falls back to `system_admin_email`) | Email of the first organization admin. |
| `smtp_from_email` | `string` | `""` | From-address for outbound mail. Empty disables SMTP. |
| `max_upload_size_bytes` | `number` | `26214400` | Max upload size (25 MiB default). |
| `storage_bucket_acl` | `string` | `"public-read"` | ACL for the uploads bucket. |
| `sidekiq_concurrency` | `number` | `5` | Sidekiq worker thread count. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-decidim`. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `uploads_bucket_name` | S3 bucket for Active Storage uploads. |
| `database_name` | PostgreSQL database name. |
| `system_admin_email` | Echoed back; password lives in the secret bag. |

## Notes

- OIDC redirect URI is `https://<hostname>/users/auth/oauth2_authentik/callback`.
- `SECRET_KEY_BASE` is pinned (`ignore_changes = all`). Rotating it invalidates every session and every encrypted attribute in the DB — taint deliberately.
- `db-init` is idempotent via an internal marker volume. To reset on a wiped database, pass `-e decidim_force_db_init=true`.
- The upstream `ghcr.io/decidim/decidim` image precompiles assets at build time. If you build a custom image, run `bundle exec rails assets:precompile` in your Dockerfile.
