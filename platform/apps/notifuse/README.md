# apps/notifuse

Notifuse — open-source transactional + marketing email manager. Single-container docker-compose stack behind Traefik. PostgreSQL is the shared instance; an S3 bucket holds marketing assets (templates, attachments). Defaults to admin-only access — Notifuse is an operator tool.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname. |
| `root_admin_email` | `string` | — (required when enabled) | Initial root admin email. |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |
| `category_group` | `string` | `"Productivity"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon. |
| `access_level` | `string` | `"admin"` | Defaults to admin-only — Notifuse is an ops tool. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `oidc_auto_provision` | `bool` | `true` | Auto-create user on first OIDC login. |
| `oidc_allow_magic_code` | `bool` | `true` | Allow magic-link login fallback alongside OIDC. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `files_bucket_name` | S3 bucket name. |
| `database_name` | PostgreSQL database. |
| `root_admin_email` | Echoed for docs; password lives in the app-secrets bag. |

## Notes

- `SECRET_KEY` and `ROOT_ADMIN_PASSWORD` are pinned (`ignore_changes = all`). `SECRET_KEY` encrypts every workspace secret — rotating it requires a re-encrypt of every workspace. `ROOT_ADMIN_PASSWORD` is the break-glass login if OIDC breaks.
- `scaleway_secret_version.app` has `ignore_changes = [data]` so peripheral fields (e.g. OIDC client_secret rotating) don't churn the version forever. Taint to force re-render.
- To recover the bootstrap admin password, pull it from the Scaleway secret printed at apply time:
  ```bash
  SECRET_ID=$(terraform output -json | jq -r '.enabled_apps.value.notifuse.ansible_vars.notifuse_app_secret_id' | sed 's|.*/||')
  scw secret version access secret-id="$SECRET_ID" revision=latest -o json \
    | jq -r '.data' | base64 -d | jq -r '.ROOT_ADMIN_PASSWORD'
  ```
