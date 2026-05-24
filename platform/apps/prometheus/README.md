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
| `tem_exporter_enabled` | `bool` | `false` | Deploy the bundled Scaleway TEM exporter sidecar. Pairs with `monitoring/dashboards/scaleway-tem.json` + `monitoring/alerts/scaleway-tem.yml`. Requires the next three vars. |
| `tem_smtp_secret_id` | `string` | `""` | Scaleway secret ID for `smtp-config` (typically `module.base.scaleway.smtp_config_secret_id`). Exporter reads the `password` field as the TEM API key. |
| `tem_scaleway_project_id` | `string` | `""` | Scaleway project the TEM domain lives in (typically `module.base.scaleway.project_id`). |
| `tem_scaleway_region` | `string` | `"fr-par"` | Scaleway region (TEM is fr-par only at time of writing). |
| `tem_exporter_poll_interval_seconds` | `number` | `60` | Poll frequency. |
| `tem_exporter_lookback_minutes` | `number` | `60` | Rolling window for bounce/spam-rate calculations. |
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

## Scaleway TEM exporter (opt-in)

Enable with `tem_exporter_enabled = true`. The bundle then deploys a Python sidecar (`prometheus-tem-exporter`) that polls Scaleway's TEM API every minute and exposes counters for outbound email volume, status breakdown, and per-flag tallies (hard_bounce / soft_bounce / spam / mailbox_full / etc.) over a rolling lookback window.

The sidecar runs the stock `python:3.12-alpine` image with `pip install` on start — no custom registry image to publish. Source lives in `ansible/roles/prometheus/files/tem-exporter/`.

The exporter reuses the TEM-scoped API key that `platform/base/terraform/tem.tf` already provisions (the SMTP password in the `smtp-config` secret is a Scaleway IAM key with `TransactionalEmailFullAccess`). No extra credential.

Shipped alongside:

- `monitoring/dashboards/scaleway-tem.json` — Grafana dashboard (bounce rate, spam rate, failure rate, throughput, exporter health).
- `monitoring/alerts/scaleway-tem.yml` — Prometheus alert rules (high bounce / spam / failure / sending backlog / exporter down). The Ansible role copies these into `/etc/prometheus/rules/` when the exporter is enabled.

Wire Grafana's alert contact points at the n8n `grafana-alert-router` webhook to fan alerts out to Slack / email / on-call.
