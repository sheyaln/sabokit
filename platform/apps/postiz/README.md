# apps/postiz

Postiz — social media scheduling + content management. OIDC, DNS record, PostgreSQL DB (Scaleway RDB) for the app, Ansible role deploying postiz + redis + temporal + temporal-postgres + elasticsearch via docker-compose.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | `any` | — | Outputs from `module.base`. |
| `hostname` | `string` | `""` | Full hostname (required when enabled). |
| `category_group` | `string` | `"Productivity"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Icon path in Authentik media. |
| `access_level` | `string` | `"delegate"` | Key in `base.authentik.groups` for baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra Authentik group IDs. Keys must be static strings. |
| `tier_cascade_enabled` | `bool` | `true` | Use the tier cascade for authorization. |
| `tier_access_level` | `string` | `"delegate"` | Lowest cascade tier admitted. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into the monitoring stack. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` for the target VM. |
| `image_tag` | `string` | `"latest"` | Postiz image tag. |
| `timezone` | `string` | `"UTC"` | IANA timezone for the container. |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |
| `social_platform_credentials` | `map(map(string))` | `{}` | Per-platform OAuth creds. See Notes. |
| `disable_registration` | `bool` | `true` | Disables Postiz's local-signup form. |
| `temporal_image_tag` | `string` | `"1.28.1"` | temporal/auto-setup tag. |
| `temporal_elasticsearch_image_tag` | `string` | `"7.17.27"` | ES tag (temporal 1.28 wants 7.17.x). |
| `temporal_postgres_image_tag` | `string` | `"16"` | Postgres tag for temporal's metadata DB. |
| `memory_limit` / `memory_reservation` | `string` | `1G` / `512M` | Postiz container limits. |
| `cpu_limit` / `cpu_reservation` | `string` | `1.0` / `0.25` | Postiz container CPU. |
| `es_heap_size` | `string` | `"256m"` | JVM heap for the temporal ES sidecar. |
| `backup_enabled` | `bool` | `true` | Contribute to backrest plan. |
| `backup_extra_paths` | `list(string)` | `[]` | Extra restic paths on top of the defaults. |
| `backup_schedule_cron` | `string` | `"0 0 2 * * *"` | 6-field cron for backup. |
| `backup_retention` | `object` | `{daily=7, weekly=4, monthly=12, yearly=1}` | Restic retention. |
| `auto_update_enabled` | `bool` | `true` | Watchtower label. |
| `autoheal_enabled` | `bool` | `true` | Autoheal label. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-postiz`. |
| `monitoring` | Monitoring contribution or `null`. |
| `required_inbound_rules` | Always `[]` — Traefik fronts everything. |
| `split_dns_entries` | Single entry mapping hostname → deployment host private IP. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `backup_plan` | Backrest plan covering `/opt/postiz` + uploads/config/temporal-pg volumes. |
| `database_name` | Postiz app DB name in Scaleway RDB. |

## Notes

- **Heavy footprint.** The bundle runs five containers (postiz, redis, temporal, temporal-postgres, elasticsearch). Plan for ~3GB RAM steady-state — ES alone reserves ~1GB by default. Don't co-locate with nextcloud or decidim on a small host.
- **Two postgres tiers.** Postiz's own data lives in Scaleway RDB (managed). Temporal's metadata DB stays in the local stack on `temporal-postgres` (bundled volume, backed up by backrest). They are intentionally not merged.
- **Local-filesystem uploads.** Postiz upstream supports Cloudflare R2 + local; generic S3 is in an open PR (gitroomhq/postiz-app#1124). This bundle ships local-only until S3 support lands upstream — uploads live in the `postiz-uploads` named docker volume, covered by the backup plan.
- **OIDC vs social-platform OAuth.** Two unrelated auth surfaces. OIDC = Postiz's user login (wired via Authentik by this module). Social-platform OAuth = the credentials Postiz uses to publish to X/LinkedIn/etc. (`social_platform_credentials` input — consumer obtains each set from the platform's developer console, bundle just plumbs through env). Empty `social_platform_credentials` = no platforms wired; Postiz silently omits each from the connect list.
- **Default tier is `delegate`, not `member`.** Scheduling posts to org-owned social accounts is sensitive enough that the lowest tier shouldn't have access by default. Lower it explicitly if your org wants broader access.
- **Social platform env var names are not consistent.** Postiz uses `X_API_KEY`/`X_API_SECRET` for X, `BEEHIIVE_*` (note the spelling), `SLACK_ID`/`SLACK_SECRET` (not `_CLIENT_`), `DISCORD_BOT_TOKEN_ID`, etc. The `social_platform_credentials` variable description lists each platform's exact env vars.
