# apps/grafana

Grafana UI behind Authentik OIDC, with Prometheus + Loki datasources pre-provisioned. Reads metrics from the `prometheus` bundle and logs from the `loki` bundle via the shared `monitoring_internal` docker network.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Public hostname. |
| `category_group` | `string` | `"Operations"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional Authentik icon. |
| `access_level` | `string` | `"admin"` | Defaults to admin-only — Grafana is ops. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | Self-scrape + log paths into monitoring. |
| `deployment_host_key` | `string` | `"management"` | Host this runs on. Should match the prometheus + loki hosts for in-network DNS. |
| `image` | `string` | `"grafana/grafana"` | Image repo. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `admin_username` | `string` | `"admin"` | Bootstrap admin username (break-glass for OIDC failures). |
| `plugins` | `list(string)` | `[]` | Comma-joined into `GF_PLUGINS_PREINSTALL`. |
| `oidc_admin_group` | `string` | `"admin"` | Authentik group mapped to Grafana `Admin` role. |
| `oidc_editor_group` | `string` | `"manager"` | Authentik group mapped to Grafana `Editor` role. Everyone else lands on `Viewer`. |
| `prometheus_url` | `string` | `"http://prometheus:9090"` | Datasource URL. Works on the shared network. |
| `loki_url` | `string` | `"http://loki:3100"` | Datasource URL. |
| `prometheus_scrape_interval` | `string` | `"30s"` | Match the prometheus bundle's `global.scrape_interval`. |
| `memory_limit` / `memory_reservation` | `string` | `"1G"` / `"256M"` | |
| `cpu_limit` / `cpu_reservation` | `string` | `"1.0"` / `"0.1"` | |
| `auto_update_enabled` | `bool` | `false` | Off by default — plugin pins can break on minor bumps. |
| `autoheal_enabled` | `bool` | `true` | |
| `backup_enabled` | `bool` | `true` | SQLite + dashboards backed up by default. |
| `backup_extra_paths` / `backup_schedule_cron` / `backup_retention` | (see vars) | — | |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or null. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-grafana`. |
| `monitoring` | Self-scrape config + log paths. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `backup_plan` | Backrest plan contribution. null when disabled. |

## Notes

- OIDC redirect URI: `https://<hostname>/login/generic_oauth`.
- Role mapping uses Authentik's `groups` claim. Default mapping: members of `admin` group → Grafana `Admin`; members of `manager` group → `Editor`; everyone else → `Viewer`. Override via `oidc_admin_group` + `oidc_editor_group` to match your Authentik group naming.
- SQLite + uploaded dashboards live in the `grafana_grafana-data` named volume. Default `backup_extra_paths` covers it.
- Dashboards: drop JSON files into the host's `/opt/grafana/provisioning/dashboards/` (subfolders become Grafana folders). The role's file-provider config picks them up automatically.
