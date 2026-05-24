# apps/watchtower

[Watchtower](https://github.com/containrrr/watchtower) — auto-update opted-in Docker containers. One container per host; watches the local Docker daemon, pulls newer image versions, restarts containers. Pure host-service: no DB, no S3, no Authentik, no DNS.

Multi-instance: instantiate this module once per host you want auto-updates on. The platform's `auto_update_enabled` per-app knob (added to every app bundle) controls which containers Watchtower touches via the standard `com.centurylinklabs.watchtower.enable` label.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `deployment_host_key` | `string` | `"apps"` | Host this Watchtower instance runs on. |
| `image` | `string` | `"containrrr/watchtower"` | Image repo. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `schedule` | `string` | `"0 0 4 * * *"` | Cron (6-field, seconds first). Default 04:00 UTC daily — offset from backrest (02:00). |
| `label_enable` | `bool` | `true` | Only touch containers with `com.centurylinklabs.watchtower.enable=true`. Flip false to watch every container on the host. |
| `scope` | `string` | `""` | Optional scope filter — useful for parallel staging+prod instances on the same host. |
| `cleanup` | `bool` | `true` | Remove old image layers after update. |
| `rolling_restart` | `bool` | `true` | Restart containers one at a time. |
| `include_stopped` | `bool` | `false` | Also update stopped containers. |
| `timezone` | `string` | `"UTC"` | IANA timezone. |
| `notifications_slack_webhook` | `string` | `""` | Optional Slack incoming-webhook for post-update summaries. Empty disables. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |

## Notes

- Default schedule is 04:00 UTC so updates don't overlap with backrest's 02:00 backup window or app-bundle nightly maintenance (typically 02:00–03:00).
- App bundles ship sensible per-app `auto_update_enabled` defaults: ON for stateless utilities (bentopdf, privacy-policy, etc.), OFF for apps with breaking-change risk (nextcloud, authentik, decidim, espocrm, n8n, jitsi). Consumers flip individual apps via their bundle's `auto_update_enabled` var.
- Watchtower needs `/var/run/docker.sock` to do its job — that's effectively root on the host. Only run on hosts you fully trust the watchtower image and registry on.
