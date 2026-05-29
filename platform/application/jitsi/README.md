# apps/jitsi

Jitsi Meet — self-hosted WebRTC video conferencing. Deploys five containers (web, prosody, jicofo, jvb, oidc-adapter) as a docker-compose stack with OIDC via an external JWT adapter.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname Jitsi is served at. |
| `category_group` | `string` | `"Communication"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image_tag` | `string` | `"stable-9823"` | Docker tag for every jitsi/* image. Pin in production. |
| `timezone` | `string` | `"UTC"` | IANA timezone for the containers. |
| `jvb_udp_port` | `number` | `10000` | UDP port the video bridge binds. Opened in the host SG automatically. |
| `jvb_stun_servers` | `string` | `"meet-jit-si-turnrelay.jitsi.net:443"` | STUN servers JVB advertises to clients. |
| `enable_lobby` | `bool` | `true` | Prosody lobby module (hosts admit guests one-by-one). |
| `enable_breakout_rooms` | `bool` | `true` | Breakout rooms in the web UI. |
| `enable_prejoin_page` | `bool` | `true` | Audio/video preview before joining. |
| `oidc_adapter_image_repo` | `string` | (sabokit fork) | Git URL the host clones to build the OIDC adapter. |
| `oidc_adapter_image_version` | `string` | `"main"` | Git ref of the adapter to build. Pin in production. |
| `oidc_log_level` | `string` | `"INFO"` | Log level for the adapter. DEBUG leaks tokens. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. Do not bind to the embedded outpost — auth runs through the adapter. |
| `authentik_application_group_id` | Per-app group `app-jitsi`. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |

## Notes

- JVB media (UDP `jvb_udp_port`) bypasses Traefik and binds directly on the host. Without that port reachable, clients connect to signaling but never see or hear each other.
- OIDC redirect URI is `https://<hostname>/oidc/redirect`. The adapter is built from source on the host — pin `oidc_adapter_image_version` to a SHA for reproducibility.
- JWT signing key and XMPP component passwords are pinned (`ignore_changes`). Rotating the JWT key drops every live meeting.
- TURN and recording (Jibri) are not shipped. For NAT-restricted networks, front the deployment with your own coturn and point `jvb_stun_servers` at it.
