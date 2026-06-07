# autoheal

[Autoheal](https://github.com/willfarrell/docker-autoheal) — restart Docker containers when their healthcheck flips to unhealthy. One container per host. Pure host-service.

Multi-instance: deploy one per host. Per-app `autoheal_enabled` knobs (added to every app bundle) control which containers get the `autoheal=true` label.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `deployment_host_key` | `string` | `"apps"` | Host this Autoheal instance runs on. |
| `image` | `string` | `"willfarrell/autoheal"` | Image repo. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `container_label` | `string` | `"autoheal"` | Label that opts a container in. Set to `all` to monitor every healthchecked container. |
| `interval_seconds` | `number` | `5` | Healthcheck poll interval. |
| `start_period_seconds` | `number` | `60` | Grace period after container start before Autoheal acts. |
| `timezone` | `string` | `"UTC"` | IANA timezone. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |

## Notes

- Only restarts containers that BOTH (a) define a HEALTHCHECK and (b) carry `autoheal=true`. App bundles ship sensible per-app `autoheal_enabled` defaults — generally ON across the board since restart-on-unhealthy is low-risk.
- Needs `/var/run/docker.sock` — effectively root on the host.
- A container that keeps going unhealthy will restart-loop. Watch logs or wire Autoheal's events into your alerting if you care.
