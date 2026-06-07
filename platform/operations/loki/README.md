# loki

[Loki](https://grafana.com/oss/loki/) — single-tenant log aggregator, filesystem-backed. Receives pushes from Alloy/Promtail agents on every host (each app declares its log paths via `monitoring.loki_log_paths`). Grafana reads logs back via its Loki datasource.

Headless — port 3100 binds to 127.0.0.1 by default. Set `private_ip_bind` to a private-network IP for remote agents.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `deployment_host_key` | `string` | `"management"` | Host this Loki runs on. |
| `image` | `string` | `"grafana/loki"` | Image repo. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `retention` | `string` | `"744h"` | Loki schema duration (~31d). |
| `ingestion_rate_mb` | `number` | `10` | Per-stream ingestion ceiling, MB/s. |
| `ingestion_burst_size_mb` | `number` | `20` | Burst tolerance. |
| `private_ip_bind` | `string` | `""` | Bind 3100 to a private IP. Empty = 127.0.0.1 only. |
| `memory_limit` / `memory_reservation` | `string` | `"1G"` / `"256M"` | Container memory. |
| `cpu_limit` / `cpu_reservation` | `string` | `"1.0"` / `"0.25"` | Container CPU. |
| `timezone` | `string` | `"UTC"` | IANA timezone. |
| `diun_watch_enabled` | `bool` | `true` | Diun new-image notification opt-in. |
| `autoheal_enabled` | `bool` | `true` | Autoheal opt-in. |
| `backup_enabled` | `bool` | `true` | Backrest plan emission. |
| `backup_extra_paths` / `backup_schedule_cron` / `backup_retention` | (see vars) | — | Standard backup knobs. Chunks + index volume included by default. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `backup_plan` | Backrest plan contribution. null when disabled. |

## Notes

- Shares `monitoring_internal` docker network with `prometheus` + `grafana`.
- Single-tenant + filesystem store is the simple-config shape. For multi-tenant or S3-backed Loki, replace `templates/loki-config.yml.j2`.
- Chunks + index live in the named volume `loki_loki-data`. Default `backup_extra_paths` covers it.
