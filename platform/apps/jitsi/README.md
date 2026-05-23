# apps/jitsi

Jitsi Meet — self-hosted WebRTC video conferencing. Self-contained bundle:

- Authentik OIDC provider + application + per-app group
- DNS A record on the consumer's base domain
- Scaleway-managed secrets bag (JWT signing key, XMPP component passwords, OIDC bag)
- Ansible role that deploys five containers as a docker-compose stack:
  - `web` (Jitsi Meet frontend, behind Traefik)
  - `prosody` (XMPP signaling, internal)
  - `jicofo` (conference focus, internal)
  - `jvb` (video bridge — **direct UDP bind to the host**)
  - `oidc-adapter` (Flask shim between Authentik OIDC and Jitsi JWT, behind Traefik on `/oidc/*`)

No database. No object storage. No Jibri (recording) in v1 — see below.

JVB's UDP media port (`jvb_udp_port`, default 10000) is added to the deployment host's security group automatically when the bundle is enabled. Disabling closes it. WebRTC media bypasses Traefik entirely — without that port open clients connect to room signaling but never see or hear each other.

Auth is OIDC via an external adapter (`github.com/sheyaln/jitsi-oidc-adapter` pinned to a tag): clients OIDC-flow through Authentik, the adapter mints a Jitsi JWT, web+prosody verify the JWT. The bundle does NOT use the embedded Authentik outpost — don't add `module.jitsi.authentik_provider_id` to `extra_forward_auth_provider_ids`.

## Usage

```hcl
module "jitsi" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/jitsi/terraform?ref=v2.3.0"
  enabled  = try(var.apps.jitsi.enabled, false)
  hostname = try(var.apps.jitsi.hostname, "")
  base     = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  jitsi = {
    enabled  = true
    hostname = "meet.example.org"
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/jitsi/ansible/playbook.yml
```

Ansible vars come from the Terraform module's `ansible.vars` output — `consumer-template/` wires this into a JSON file the playbook reads via `-e @.ansible-vars.json`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. When false the bundle provisions zero resources. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname Jitsi is served at. |
| `category_group` | `string` | `"Communication"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | If true and a monitoring app is enabled, log paths wire up. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` identifying the deploy target. |
| `image_tag` | `string` | `"stable-9823"` | Docker tag for every jitsi/* image. Pin in production. |
| `timezone` | `string` | `"UTC"` | IANA timezone for the containers. |
| `jvb_udp_port` | `number` | `10000` | UDP port the video bridge binds. **Must be opened in the Scaleway SG too.** |
| `jvb_stun_servers` | `string` | `"meet-jit-si-turnrelay.jitsi.net:443"` | STUN servers JVB advertises to clients. |
| `enable_lobby` | `bool` | `true` | Whether the prosody lobby module is on (hosts admit guests one-by-one). |
| `enable_breakout_rooms` | `bool` | `true` | Whether the web UI exposes breakout rooms. |
| `enable_prejoin_page` | `bool` | `true` | Whether participants see the audio/video preview before joining. |
| `oidc_adapter_image_repo` | `string` | (sabokit fork) | Git URL the host clones to build the OIDC adapter. |
| `oidc_adapter_image_version` | `string` | `"main"` | Git ref (tag/branch/SHA) of the adapter to build. **Pin in production.** |
| `oidc_log_level` | `string` | `"INFO"` | Log level for the adapter. DEBUG leaks tokens. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. Don't bind to the embedded outpost. |
| `authentik_application_group_id` | Per-app group `app-jitsi`. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}` consumed by site.yml. |

## What lands on the host

After `terraform apply && ansible-playbook site.yml`:

- `/opt/jitsi/docker-compose.yml` — managed file (mode 0644)
- `/opt/jitsi/.env` — managed file (mode 0600, plaintext secrets re-fetched from Scaleway Secret Manager on every play)
- `/opt/jitsi/{web,prosody,jicofo,jvb,transcripts}/` — per-container config bind mounts
- `/opt/jitsi/oidc-adapter/` — git checkout that becomes the build context for the adapter image
- Five containers: `jitsi-web`, `jitsi-prosody`, `jitsi-jicofo`, `jitsi-jvb`, `jitsi-oidc-adapter`
- UFW rule: `allow <jvb_udp_port>/udp` (the role manages this)

## Disabling

Set `apps.jitsi.enabled = false` in tfvars and `terraform apply`. Terraform destroys the Authentik resources, the DNS record, and the Scaleway secret. The compose stack and `/opt/jitsi/` survive on the host — `ssh apps && cd /opt/jitsi && docker compose down -v && sudo rm -rf /opt/jitsi` to fully remove. The UFW rule is not auto-removed; `sudo ufw delete allow 10000/udp`.

## Notes

- **JWT signing key rotation drops every live meeting.** The Scaleway secret has `ignore_changes = [data]` to avoid accidental churn. Rotate by creating a new secret version manually and re-running the playbook.
- **Recording (Jibri) is not shipped in v1.** The bundle generates `JIBRI_*` passwords so a future Jibri add-on doesn't force a re-rotation of every other secret, but no `jibri` container runs. Adding Jibri also requires loopback ALSA/V4L2 modules on the host kernel and a non-trivial chrome-in-container setup — out of scope here.
- **TURN is not shipped.** JVB advertises the public Jitsi STUN relay by default. For networks where peer-to-peer ICE fails (NAT hairpinning, restrictive firewalls), front the deployment with your own coturn and set `jvb_stun_servers` to its `host:port`. The bundle doesn't deploy coturn itself.
- **The OIDC adapter is built from source on the host.** That's a fragile pattern; a future revision should switch to a published image. Pin `oidc_adapter_image_version` to a SHA in production so re-deploys are reproducible.
- The OIDC redirect URI is `https://<hostname>/oidc/redirect` (the adapter's convention).
