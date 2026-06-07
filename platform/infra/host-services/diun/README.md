# base/host-services/diun

[Diun](https://github.com/crazy-max/diun) — receive notifications when a new image is available on a registry for any container running on the host. One container per host; watches the local Docker daemon, polls each image's registry on a schedule, fires a notification when a tag's digest changes. Pure host-service: no DB, no S3, no Authentik, no public hostname.

Replaces the legacy `apps/watchtower` bundle (Watchtower upstream was archived 2025-12-17). Behaviour shift: Diun **notifies**, it does NOT pull or restart. Operator (or an n8n workflow) decides whether/when to apply each update.

Auto-instantiated per `var.compute_hosts` entry from `platform/infra/terraform/host_services.tf` at v3.4.0+. Consumer surface is `var.base.diun.{enabled, disabled_hosts, ...}` — see `platform/infra/terraform/variables.tf`. Not called as a standalone module from consumer-template.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `deployment_host_key` | `string` | `"management"` | Host this Diun instance runs on. |
| `instance_name` | `string` | `""` | Suffix for namespacing when running multiple Diun instances under one base. Empty = single instance. |
| `image_tag` | `string` | `"4.31.0"` | Diun Docker image tag. |
| `timezone` | `string` | `"UTC"` | IANA timezone. |
| `watch_schedule` | `string` | `"0 0 6 * * *"` | Cron (6-field, seconds first). Default daily at 06:00 UTC. |
| `watch_workers` | `number` | `10` | Concurrent image-check workers. |
| `watch_first_check_notif` | `bool` | `false` | Notify for images never seen before (i.e. flood on first boot). |
| `watch_by_default` | `bool` | `true` | Watch every container without needing per-container opt-in label. |
| `default_watch_repo` | `bool` | `false` | Watch all tags of every image vs only the exact tag in use. |
| `include_swarm_services` | `bool` | `false` | Enable docker-swarm-mode provider. |
| `n8n_webhook_url` | `string` | `""` | Webhook URL Diun POSTs new-image events to. Auto-derived from the n8n bundle by the consumer-template when n8n is enabled. |
| `diun_notif_extra` | `map(any)` | `{}` | Extra notification providers keyed by Diun notifier type (slack, mail, …). Value passed verbatim into `notif:` in diun.yml. |
| `notification_targets` | `list(any)` | `[]` | Legacy list-shaped notifier config kept for pre-v3.2 consumers. |
| `diun_watch_enabled` | `bool` | `false` | Whether Diun watches its own image for updates. |
| `autoheal_enabled` | `bool` | `true` | Whether Autoheal restarts Diun on healthcheck failure. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into Loki when monitoring is enabled. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `monitoring` | Loki log paths only. Diun does not expose `/metrics` natively. |
| `instance_name` | Echoed back for indexing convenience. |
| `split_dns_entries` / `required_inbound_rules` / `backup_plan` / `blackbox_targets` | Empty / null — Diun is outbound-only with rebuildable state. |

## Notes

- **Notify, don't restart.** Diun fires notifications when a tag's digest changes upstream. It does NOT pull or restart anything. This is the deliberate v3.2 shift away from Watchtower's auto-update model — visibility + operator control over update timing.
- **Per-bundle opt-in.** Every app bundle ships a `diun_watch_enabled` knob (default true) that emits a `diun.enable=true` compose label. Combined with `watch_by_default=true` (this bundle's default) every container on the host is watched out of the box; flip `watch_by_default=false` to require explicit labels.
- **n8n webhook auto-wire.** The consumer-template auto-derives `n8n_webhook_url` as `<n8n_url>/webhook/diun-image-update` when the n8n bundle is enabled (mirrors the TEM → n8n auto-wire pattern). The recommended fan-out target is an n8n workflow that routes to Slack / email / JSM.
- **Empty notif targets = stdout-only.** If neither `n8n_webhook_url`, `notification_targets`, nor `diun_notif_extra` is populated, Diun still logs new-image events to stdout; Loki picks them up.
- **`diun_notif_extra` shape** mirrors Diun's YAML config exactly: `{ slack = { webhook_url = "..." }, mail = { host = "...", port = 587, ... } }`. Pass-through to `notif:` in diun.yml. See https://crazymax.dev/diun/notif/ for per-notifier schemas.
- `diun_watch_enabled` on this bundle defaults false — auto-monitoring the tool whose job is to gate updates is low-signal; bump Diun manually after reviewing the upstream changelog.
- Diun needs `/var/run/docker.sock` (read-only) to introspect sibling containers. Root-equivalent trust posture; only run on hosts where you trust the Diun image + its registry.
