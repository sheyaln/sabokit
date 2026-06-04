# apps/espocrm

EspoCRM — open-source PHP CRM for tracking customers, members, donors, or any other constituent relationship. Deploys EspoCRM + its cron daemon as a docker-compose stack behind Traefik. PostgreSQL is the shared instance; the rest lives in the `espocrm-data` named volume. **Back up that volume** — it holds `data/config.php` plus the application files. No S3, no Redis. After deploy, three PHP bootstrap scripts are `docker cp`'d in to wire OIDC, optional member entities, and optional webhooks.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname EspoCRM is served at. |
| `category_group` | `string` | `"Tools"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `authorized_groups` | `list(string)` | `["delegate"]` | Authentik group names allowed in. CRM holds member PII → delegates and up by default; higher tiers nest under lower. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image_tag` | `string` | `"latest"` | EspoCRM Docker image tag. |
| `timezone` | `string` | `"UTC"` | IANA timezone for the container and the app's runtime config. |
| `admin_username` | `string` | `"admin"` | Local admin username (break-glass; OIDC is the primary path). |
| `b2c_mode` | `bool` | `true` | Enable "Business to Consumer" mode (simpler UI; hides Accounts). |
| `oidc_username_claim` | `string` | `"email"` | OIDC claim used as the EspoCRM username. |
| `oidc_group_claim` | `string` | `"groups"` | OIDC claim carrying group memberships. |
| `oidc_team_id_prefix` | `string` | `"sso-"` | Prefix used when auto-creating EspoCRM teams from OIDC groups. |
| `oidc_group_role_mapping` | `map(string)` | `{}` | `{ authentik_group_name: EspoCRM Role Name }`. Roles must already exist (built-in or provisioned by member-entity bootstrap). |
| `enable_member_entity_bootstrap` | `bool` | `false` | Provisions `Member` + `DuesPayment` entities, four roles + matching teams, navbar, and hides default sales-CRM entities. Leave off for a generic sales CRM. |
| `member_entity_webhooks` | `list(object)` | `[]` | Webhook rows upserted into the `webhook` table. Object: `{id, name, event, type, field, url}`. Upsert key is `id`, so re-applies are safe. |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-espocrm`. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `database_name` | PostgreSQL database name. |

## Notes

- OIDC redirect URI is `https://<hostname>/oauth-callback.php`.
- The admin fallback password lives in the Scaleway secret bag with `ignore_changes = all` — regenerating in Terraform would diverge from the in-DB value. Rotate by tainting `random_password.admin` AND updating the `users` row in concert.
- The `espocrm-daemon` container drains the scheduled-job queue. Without it, reminders, notifications, and **webhook delivery** stall.
- EspoCRM exposes no REST API for the OIDC config keys before an admin signs in, so the bootstrap edits `data/config.php` directly. Re-running it overwrites the OIDC keys and upserts roles/teams/webhooks; fields it doesn't manage are left alone.
