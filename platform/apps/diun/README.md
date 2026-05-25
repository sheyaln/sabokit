# apps/diun

[Diun](https://github.com/crazy-max/diun) — receive notifications when a new image is available on a registry for any container running on the host. One container per host; watches the local Docker daemon, polls each image's registry on a schedule, fires a notification when a tag's digest changes. Pure host-service: no DB, no S3, no Authentik, no public hostname.

Multi-instance: instantiate this module once per host you want notification coverage on. Pairs with Watchtower as a deliberate split — Diun notifies, an operator (or the consumer's automation) decides whether/when to pull. `auto_update_enabled` defaults to false on this bundle on purpose.

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
| `notification_targets` | `list(any)` | `[]` | Diun notifier configs — see Notes. |
| `auto_update_enabled` | `bool` | `false` | Whether Watchtower auto-updates Diun itself. |
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

- **Notify, don't restart.** Diun fires notifications when a tag's digest changes upstream. It does NOT pull or restart anything — that's Watchtower's job, and the two bundles ship side-by-side on purpose. Use Diun when you want visibility + control over when updates land; use Watchtower when you want unattended auto-update for specific containers.
- `watch_by_default = true` (default) means Diun watches every container on the host without per-container labels. Bundles can still override with `diun.*` container labels — see https://crazymax.dev/diun/providers/docker/ for the full label set.
- `notification_targets` shape: each entry is `{ type = "<notifier>", config = { ... } }`. Supported notifier types: `amqp`, `discord`, `gotify`, `mail`, `matrix`, `mqtt`, `ntfy`, `opsgenie`, `pushover`, `rocketchat`, `script`, `slack`, `teams`, `telegram`, `twilio`, `webhook`. `config` is passed through to Diun's `diun.yml` verbatim — option names and shapes preserved. See https://crazymax.dev/diun/notif/ for per-type schemas.
- **Empty `notification_targets` = stdout-only.** Diun still logs new-image events; Loki picks them up via `loki_log_paths`. Useful for getting started; wire a real notifier when you want pushed alerts.
- **Recommended integration**: one `webhook` entry pointing at the n8n bundle's `/webhook/diun-new-image` workflow (`platform/apps/n8n/.../files/workflows/diun-notification-router.json`), then fan out from n8n to Slack / email / JSM. Mirrors the `grafana-alert-router` pattern.
- `auto_update_enabled` defaults false on this bundle specifically. Auto-updating the tool whose job is to gate updates defeats the point — bump Diun manually after reviewing the upstream changelog.
- Diun needs `/var/run/docker.sock` (read-only) to introspect sibling containers. Same root-equivalent trust posture as Watchtower; only run on hosts you fully trust the Diun image + its registry on.
