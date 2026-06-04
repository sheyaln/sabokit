# apps/steward

[Steward](https://github.com/sheyaln/sabokit-steward) — friendly Authentik admin UI for non-technical organization admins (membership secretaries, organizers, chapter admins). OIDC login plus a non-expiring Authentik API token for server-to-server admin calls; PostgreSQL DB for Steward's audit log and import-job state; Ansible role deploying `web` + `qcluster` containers behind Traefik. Authentik remains the source of truth — Steward holds no local user mirror.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | `any` | — | Outputs from `module.base`. |
| `hostname` | `string` | `""` | Full hostname (required when enabled). |
| `category_group` | `string` | `"Administration"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Icon path in Authentik media. |
| `authorized_groups` | `list(string)` | `["delegate"]` | Authentik group names allowed in. Member-admin surface → delegates and up by default; higher tiers nest under lower. |
| `monitoring_enabled` | `bool` | `true` | Contribute to the monitoring aggregate. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` for the target VM. |
| `image_repository` | `string` | `"ghcr.io/sheyaln/sabokit-steward"` | OCI repo (without tag). Repoint to a mirror if needed. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `admin_group_name` | `string` | `"steward-admins"` | Authentik group name whose members get Steward admin rights. Include it in `authorized_groups` (or a higher tier nested under one) so the OIDC `groups` claim carries it. |
| `invite_flow_slug` | `string` | `""` | Authentik enrollment-flow slug attached to invitations (e.g. `default-source-enrollment`). Empty disables invitation creation. |
| `memory_limit` | `string` | `"512M"` | Web container memory cap. |
| `memory_reservation` | `string` | `"128M"` | Web container memory reservation. |
| `cpu_limit` | `string` | `"0.5"` | Web container CPU cap. |
| `cpu_reservation` | `string` | `"0.1"` | Web container CPU reservation. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-steward`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `database_name` | PostgreSQL database name. |
| `service_steward_token_secret_hint` | Pointer to where the Authentik API token lives in the app-secrets bag. |

## Notes

- Default `authorized_groups` is `["delegate"]` — Steward delegates member management to officers; admins reach it via group nesting.
- Service account: `authentik_user.service_steward` with username + email `svc-steward@<base_domain>` (platform convention: resource name `service_<thing>`, username/email `svc-<thing>`). Lands in Authentik's built-in `authentik Admins` group — broader than Steward strictly needs. A future iteration should narrow this to a custom role.
- Database migrations run on every `web` container start; the `qcluster` sidecar opts out.
- Break-glass: `docker exec -it steward-web python manage.py createsuperuser`, then `/admin/`. OIDC is the normal entry point.
