# apps/broadsheet

Broadsheet — newsletters + transactional email manager. Ships the [sabokit-broadsheet](https://github.com/sheyaln/sabokit-broadsheet) fork of notifuse: same delivery engine, rebranded UI, fork carries the OIDC patches. Single-container docker-compose stack behind Traefik. PostgreSQL is the shared instance; an S3 bucket holds marketing assets. Defaults to admin-only access — Broadsheet is an operator tool.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname. |
| `root_admin_email` | `string` | — (required when enabled) | Initial root admin email. |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |
| `category_group` | `string` | `"Productivity"` | Authentik portal category. |
| `icon_filename` | `string` | `"broadsheet-icon.png"` | Fetched from `base.authentik.icon_base_url`. |
| `icon_url` | `string` | `""` | Full URL override; bypasses `icon_filename`. |
| `access_level` | `string` | `"admin"` | Defaults to admin-only — Broadsheet is an ops tool. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image` | `string` | `"ghcr.io/sheyaln/broadsheet"` | Published image. Used by default. |
| `image_tag` | `string` | `"latest"` | Image tag. Pin in production. |
| `build_from_source` | `bool` | `false` | Opt-in: build the image on the host from `image_source_repo` instead of pulling. For unreleased fork patches only. |
| `image_source_repo` | `string` | `"https://github.com/sheyaln/sabokit-broadsheet.git"` | Git URL cloned when `build_from_source = true`. |
| `image_source_ref` | `string` | `"main"` | Git ref checked out. Pin to a tag/SHA for reproducibility. |
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
| `backup_plan` | Backrest plan contribution. null when disabled. |

## Notes

- Default deploy pulls `ghcr.io/sheyaln/broadsheet:latest`. Flip `build_from_source = true` only when you need an unreleased fork patch — that clones `github.com/sheyaln/sabokit-broadsheet @ main` to `/opt/broadsheet/src` and builds locally (~3 min first deploy, image tagged `broadsheet-local:latest`).
- Traefik labels are namespaced `broadsheet` (v3.2.1). The internal docker compose service name remains `notifuse` because the bundled binary still uses that name internally — purely cosmetic, no external surface.
- `SECRET_KEY` and `ROOT_ADMIN_PASSWORD` are pinned (`ignore_changes = all`). `SECRET_KEY` encrypts every workspace secret — rotating it requires a re-encrypt of every workspace. `ROOT_ADMIN_PASSWORD` is the break-glass login if OIDC breaks.
- `scaleway_secret_version.app` has `ignore_changes = [data]` so peripheral fields (e.g. OIDC client_secret rotating) don't churn the version forever. Taint to force re-render.
- To recover the bootstrap admin password, pull it from the Scaleway secret printed at apply time:
  ```bash
  SECRET_ID=$(terraform output -json | jq -r '.enabled_apps.value.broadsheet.ansible_vars.broadsheet_app_secret_id' | sed 's|.*/||')
  scw secret version access secret-id="$SECRET_ID" revision=latest -o json \
    | jq -r '.data' | base64 -d | jq -r '.ROOT_ADMIN_PASSWORD'
  ```
