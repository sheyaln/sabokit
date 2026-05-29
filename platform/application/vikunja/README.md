# apps/vikunja

Vikunja — open-source task and project tracker. OIDC, DNS record, PostgreSQL DB, secrets bag, Ansible role deploying a single-container docker-compose stack with a host-side bind mount for attachments. No S3, no Redis — Vikunja keeps state in Postgres plus a filesystem volume.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | `any` | — | Outputs from `module.base`. |
| `hostname` | `string` | `""` | Full hostname (required when enabled). |
| `category_group` | `string` | `"Productivity"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` for baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra Authentik group IDs. Keys must be static strings. |
| `monitoring_enabled` | `bool` | `true` | Contribute to the monitoring aggregate. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` for the target VM. |
| `image_tag` | `string` | `"latest"` | Vikunja image tag. |
| `timezone` | `string` | `"UTC"` | IANA timezone. Affects reminder times and recurring-task scheduling. |
| `enable_registration` | `bool` | `false` | Built-in local-account signup. Inert while `enable_local_auth = false`. |
| `enable_local_auth` | `bool` | `false` | Allow username+password login alongside OIDC. |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |
| `oidc_groups_scope_name` | `string` | `"vikunja_scope"` | Authentik custom-scope name carrying the `vikunja_groups` claim for team auto-assignment. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-vikunja`. |
| `monitoring` | Monitoring contribution or `null`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `database_name` | PostgreSQL database name. |

## Notes

- OIDC redirect URI is `https://<hostname>/auth/openid/authentik`.
- The `vikunja_scope` OIDC scope is NOT created by this bundle. Define it manually in Authentik with a `vikunja_groups` mapping if you want team auto-assignment; OIDC login works regardless.
- `/opt/vikunja/files/` is a host bind-mount holding uploaded attachments. Back it up explicitly — backrest's default Postgres dump misses it.
