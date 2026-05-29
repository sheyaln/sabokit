# apps/outline

Outline — Markdown-first knowledge base. OIDC, DNS record, S3 bucket for attachments, PostgreSQL DB, secrets bag, Ansible role deploying Outline + Redis via docker-compose. ARCHITECTURE.md uses this bundle as its worked example.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | `any` | — | Outputs from `module.base`. |
| `hostname` | `string` | `""` | Full hostname (required when enabled). |
| `category_group` | `string` | `"Knowledge"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` for baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra Authentik group IDs. Keys must be static strings. |
| `monitoring_enabled` | `bool` | `true` | Contribute to the monitoring aggregate. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` for the target VM. |
| `image_tag` | `string` | `"latest"` | Outline image tag. |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |
| `max_upload_size_bytes` | `number` | `26214400` | 25 MiB default. |
| `storage_bucket_acl` | `string` | `"public-read"` | Outline needs public-read for shared-doc attachments. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-outline`. |
| `monitoring` | Monitoring contribution or `null`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `attachments_bucket_name` | S3 bucket name. |
| `database_name` | PostgreSQL database name. |

## Notes

- OIDC redirect URI is `https://<hostname>/auth/oidc.callback`.
- Outline exposes no Prometheus metrics — monitoring contribution is log paths + Traefik router metrics only.
- The attachments bucket name embeds `base.scaleway.secrets_namespace`; collisions on the global S3 namespace require changing `base.org_slug`.
