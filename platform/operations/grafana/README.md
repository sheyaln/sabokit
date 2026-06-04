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
| `authorized_groups` | `list(string)` | `["admin"]` | Authentik group names allowed in. Ops dashboards → admin-only by default; higher tiers nest under lower. |
| `monitoring_enabled` | `bool` | `true` | Self-scrape + log paths into monitoring. |
| `deployment_host_key` | `string` | `"management"` | Host this runs on. Co-locate with prometheus + loki for in-network DNS (`http://prometheus:9090`, `http://loki:3100`), or split them across hosts and let the base `split-dns` role bridge them via the public hostnames. |
| `image` | `string` | `"grafana/grafana"` | Image repo. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `admin_username` | `string` | `"admin"` | Bootstrap admin username (break-glass for OIDC failures). |
| `plugins` | `list(string)` | `[]` | Comma-joined into `GF_PLUGINS_PREINSTALL`. |
| `oidc_admin_group` | `string` | `"admin"` | Authentik group mapped to Grafana `Admin` role. |
| `oidc_editor_group` | `string` | `"manager"` | Authentik group mapped to Grafana `Editor` role. Everyone else lands on `Viewer`. |
| `grafana_dashboards` | `list(object({filename, contents}))` | `[]` | Dashboards to provision via the file provider. Consumer aggregates every enabled app's `monitoring.grafana_dashboards` paths into this. File provider auto-reloads (30s poll), no restart. |
| `jsm_api_key_secret_id` | `string` | `""` | Scaleway secret holding the JSM Operations (heritage Opsgenie) API integration key as `{"api_key": "..."}`. Empty = no JSM provisioning, root policy uses Grafana's built-in default. Non-empty = `jsm-default` contact point + root policy routed to it. |
| `jsm_api_region` | `string` | `"us"` | `us` or `eu`. Picks the api.atlassian.com vs api.eu.atlassian.com endpoint. |
| `jsm_priority_mapping` | `map(string)` | `{critical=P1, warning=P3, info=P5}` | Grafana `severity` label -> JSM priority. |
| `jsm_alert_tags` | `list(string)` | `["sabokit"]` | Tags on every JSM alert. Routing hook on the JSM side. |
| `jsm_severity_gate` | `string` | `""` | Empty = JSM is the root contact (existing behaviour). Non-empty (e.g. `"critical"`) = root stays on Grafana's built-in `grafana-default` contact (wire it to n8n / your own fan-out separately) and JSM moves to a child policy matching `severity = <value>` with `continue: true`. Composes with the other `jsm_*` knobs. |
| `prometheus_url` | `string` | `"http://prometheus:9090"` | Datasource URL. Works on the shared network. |
| `loki_url` | `string` | `"http://loki:3100"` | Datasource URL. |
| `prometheus_scrape_interval` | `string` | `"30s"` | Match the prometheus bundle's `global.scrape_interval`. |
| `memory_limit` / `memory_reservation` | `string` | `"1G"` / `"256M"` | |
| `cpu_limit` / `cpu_reservation` | `string` | `"1.0"` / `"0.1"` | |
| `diun_watch_enabled` | `bool` | `true` | Diun new-image notification opt-in. |
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
- Dashboards: app bundles ship dashboards via `monitoring.grafana_dashboards` (file paths); the consumer aggregates and passes them as `grafana_dashboards`. Operators can also drop JSON files into the host's `/opt/grafana/provisioning/dashboards/` out-of-band; both routes flow through the same file provider.
- JSM: when `jsm_api_key_secret_id` is set, every alert that fires gets POSTed to JSM Operations via Grafana's native `opsgenie` contact point. Existing v2.11.0 consumers who don't set the var see no behaviour change. Setting it for the first time on an upgrade — alerts start paging JSM on the next ansible run. The n8n `grafana-alert-router` workflow stays available as an additional/alternative routing path; wire it in as a second contact point on Grafana's side if you want slack/email fan-out alongside JSM.
