# apps/prometheus

Prometheus TSDB + (optional) `node_exporter` + `cadvisor` sidecars on one host. Headless — internal-only via Grafana or SSH tunnel by default; bind to a private-network IP to let other hosts on the VPC scrape directly.

Scrape configs and alert rules are aggregated by the consumer from each enabled app's `monitoring.prometheus_scrape_configs` and `monitoring.alert_rules` outputs. Bundles own their scraping; consumer just plumbs.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `deployment_host_key` | `string` | `"management"` | Host this Prometheus runs on. |
| `image` | `string` | `"prom/prometheus"` | Image repo. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `retention` | `string` | `"30d"` | TSDB retention window (Prometheus duration). |
| `scrape_configs` | `list(any)` | `[]` | Extra scrape_config entries beyond defaults. Consumer aggregates each app's `monitoring.prometheus_scrape_configs`. |
| `alert_rules` | `list(any)` | `[]` | Alerting rule groups. Consumer aggregates each app's `monitoring.alert_rules`. |
| `exporters_enabled` | `bool` | `true` | Deploy node_exporter + cadvisor sidecars + default scrape jobs for them. |
| `remote_write_enabled` | `bool` | `true` | Enable the remote-write receiver endpoint. |
| `private_ip_bind` | `string` | `""` | Bind 9090 to a private IP. Empty = 127.0.0.1 only. |
| `memory_limit` / `memory_reservation` | `string` | `"2G"` / `"512M"` | Container memory. |
| `cpu_limit` / `cpu_reservation` | `string` | `"2.0"` / `"0.5"` | Container CPU. |
| `timezone` | `string` | `"UTC"` | IANA timezone. |
| `auto_update_enabled` | `bool` | `false` | Watchtower opt-in. Default off — Prometheus has TSDB compatibility quirks; let Ansible drive bumps. |
| `autoheal_enabled` | `bool` | `true` | Autoheal opt-in. |
| `backup_enabled` | `bool` | `true` | Backrest plan emission. TSDB is in the named volume; restic backs up by default. |
| `backup_extra_paths` / `backup_schedule_cron` / `backup_retention` | (see vars) | — | Standard backup knobs. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `backup_plan` | Backrest plan contribution (TSDB + config). null when disabled. |

## Notes

- Shares the `monitoring_internal` docker network with `loki` and `grafana` so Grafana can reach Prometheus by hostname. Each of the three bundles creates the network with `state: present` (idempotent — first one wins).
- `node_exporter` runs with `pid: host` and a read-only bind of `/`. `cadvisor` runs privileged with `/var/lib/docker` mounted RO. Both are standard for the metrics they collect; disable via `exporters_enabled = false` if you'd rather wire your own.
- Reload-only config changes (scrape configs, alert rules) trigger Prometheus's `POST /-/reload` endpoint instead of a container restart.
- TSDB lives in the named volume `prometheus_prometheus-data`. The default `backup_extra_paths` covers it.
