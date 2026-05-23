# apps/nextcloud

Nextcloud + OnlyOffice Document Server + Talk HPB (high-performance backend
for video calls). One bundle, one Terraform module, one Ansible role, one
docker-compose stack — three URLs to the user.

What's provisioned:

- Authentik OIDC provider + application + per-app group
- Three DNS A records (Nextcloud, OnlyOffice, Talk HPB) on the consumer's base domain
- PostgreSQL database + user (Nextcloud only — OnlyOffice runs the postgres bundled in its image)
- S3 bucket for primary storage (all user files live there, not on the host disk)
- Scaleway-managed secrets bag (admin password, Redis password, OIDC + S3 config, SMTP from-address, OnlyOffice JWT + secure-link, Talk TURN/signaling/internal secrets)
- Ansible role that deploys five containers (Nextcloud, Redis, cron, OnlyOffice, Talk HPB) as a single docker-compose stack with Traefik routing, then runs an idempotent `occ` script to wire up Redis, OIDC, the OnlyOffice connector, the Talk `spreed` app, trusted_proxies, and Scaleway-S3 integrity flags

Talk HPB's TURN + UDP relay ports get added to the deployment host's security group automatically when the bundle is enabled (via the aggregated `required_inbound_rules` output in `consumer-template/modules/stack/`). Disabling the bundle closes them.

Image tag pinning: default is `32-apache`. Nextcloud only supports one-major-at-a-time upgrades — step through each major (`32` → `33` → `34`), don't jump.

## Usage

```hcl
module "nextcloud" {
  source              = "git::https://github.com/sheyaln/sabokit.git//platform/apps/nextcloud/terraform?ref=v2.3.0"
  enabled             = try(var.apps.nextcloud.enabled, false)
  hostname            = try(var.apps.nextcloud.hostname, "")
  onlyoffice_hostname = try(var.apps.nextcloud.onlyoffice_hostname, "")
  talk_hostname       = try(var.apps.nextcloud.talk_hostname, "")
  base                = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  nextcloud = {
    enabled             = true
    hostname            = "cloud.example.org"
    onlyoffice_hostname = "docs.example.org"
    talk_hostname       = "talk.example.org"
    smtp_from_email     = "cloud@example.org"  # optional
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/nextcloud/ansible/playbook.yml
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname Nextcloud is served at. |
| `onlyoffice_hostname` | `string` | — (required when enabled) | Full hostname OnlyOffice Document Server is served at. |
| `talk_hostname` | `string` | — (required when enabled) | Full hostname Talk HPB signaling is served at over WSS. Same DNS name is also where clients hit TURN on UDP/TCP 3478. |
| `category_group` | `string` | `"Files"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups allowed beyond `access_level`. Keys are static role names. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image_tag` | `string` | `"32-apache"` | Nextcloud image tag. Pin to a major. |
| `admin_username` | `string` | `"ncadmin"` | Bootstrap admin username. |
| `default_phone_region` | `string` | `"US"` | ISO 3166-1 alpha-2 region for phone-number formatting. |
| `max_upload_size_bytes` | `number` | `2147483648` | 2 GiB. Apache body limit tracks this. |
| `trusted_proxies` | `string` | `"172.16.0.0/12"` | CIDR trusted as reverse proxy (default covers Docker bridge). |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |
| `onlyoffice_image_tag` | `string` | `"latest"` | OnlyOffice Document Server image tag. |
| `onlyoffice_memory_limit` | `string` | `"2G"` | Memory ceiling for the OnlyOffice container. |
| `onlyoffice_cpu_limit` | `string` | `"2.0"` | CPU ceiling for the OnlyOffice container. |
| `talk_image_tag` | `string` | `"latest"` | Tag for `ghcr.io/nextcloud-releases/aio-talk`. |
| `talk_turn_port` | `number` | `3478` | TCP/UDP port for eturnal TURN. Must be open in the security group. |
| `talk_relay_port_min` | `number` | `49152` | Lower bound of the eturnal UDP relay range. |
| `talk_relay_port_max` | `number` | `49252` | Upper bound of the eturnal UDP relay range. |
| `talk_memory_limit` | `string` | `"1G"` | Memory ceiling for the Talk HPB container. |
| `talk_cpu_limit` | `string` | `"1.0"` | CPU ceiling for the Talk HPB container. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-nextcloud`. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `data_bucket_name` | S3 bucket name used for primary storage. |
| `database_name` | PostgreSQL database name. |

## What lands on the host

After `terraform apply && ansible-playbook site.yml`:

- `/opt/nextcloud/docker-compose.yml` — managed file (mode 0644)
- `/opt/nextcloud/.env` — managed (mode 0600; contains plaintext secrets re-fetched from Scaleway Secret Manager on every play)
- `/opt/nextcloud/nextcloud-custom.ini` — PHP overrides (OPcache, upload limits)
- `/opt/nextcloud/configure-nextcloud.sh` — idempotent post-install occ wiring (Redis, OIDC, OnlyOffice connector, Talk spreed app + TURN/STUN/signaling, trusted_proxies, S3 integrity flags, SMTP)
- Docker volumes: `nextcloud_redis-data`, `nextcloud_nextcloud-data`, `nextcloud_nextcloud-fontcache`, `nextcloud_nextcloud-wwwcache`, `nextcloud_onlyoffice-data`, `nextcloud_onlyoffice-logs`, `nextcloud_onlyoffice-cache`, `nextcloud_onlyoffice-fonts`
- Five containers: `nextcloud-app` (Traefik on `hostname`), `nextcloud-redis`, `nextcloud-cron`, `nextcloud-onlyoffice` (Traefik on `onlyoffice_hostname`), `nextcloud-talk` (Traefik on `talk_hostname` for WSS, plus host-bound ports for TURN)

User files live in the S3 bucket, not on the host. The local `nextcloud-data` volume only holds Nextcloud's PHP installation, apps, and metadata. OnlyOffice keeps its working state in its own volumes; the bundled postgres + redis inside the documentserver image are intentional — we don't externalize them, which keeps the bundle a single stack.

## Recovering admin access

The bootstrap admin password is in the Scaleway secret. Pull it with `scw secret version access`:

```bash
SECRET_ID=$(terraform output -json | jq -r '.enabled_apps.value.nextcloud.ansible_vars.nextcloud_app_secret_id' | sed 's|.*/||')
scw secret version access secret-id="$SECRET_ID" revision=latest -o json \
  | jq -r '.data' | base64 -d | jq -r '.NEXTCLOUD_ADMIN_PASSWORD'
```

Use that with `NEXTCLOUD_ADMIN_USER` (default `ncadmin`) to sign in if OIDC isn't yet working. Once OIDC is verified, set a long random password through the admin UI and stop using the bootstrap account.

## Disabling

`apps.nextcloud.enabled = false` + `terraform apply`. Terraform destroys the Authentik resources, three DNS records, S3 bucket (⚠ all user files lost), database (⚠ all metadata lost), and secrets. The compose stack on the host is **not** auto-torn-down — `ssh apps && cd /opt/nextcloud && docker compose down -v && sudo rm -rf /opt/nextcloud`.

## Notes

- The OIDC redirect URI is `https://<hostname>/apps/user_oidc/code` (Nextcloud's `user_oidc` app convention).
- The S3 bucket name is `<base.scaleway.secrets_namespace>-nextcloud-data` and must be globally unique across all Scaleway customers.
- `OBJECTSTORE_S3_USEPATH_STYLE=false` because Scaleway supports virtual-hosted-style buckets and path-style triggers redirects.
- The configure script sets `request_checksum_calculation=when_required` to work around Scaleway's CRC32 trailing-checksum rejection on Nextcloud 32+.
- The configure script sets `allow_local_remote_servers=true` so OIDC + federation calls work when public hostnames resolve to VPC private IPs (split-horizon DNS); remove this if your VPC doesn't use split-horizon.
- OnlyOffice's `ALLOW_PRIVATE_IP_ADDRESS=true` is required: Nextcloud's server-to-server callbacks reach the documentserver via the internal Docker hostname (RFC1918) and the image's nginx otherwise refuses them.
- The Talk HPB container's wrapper entrypoint patches `eturnal.yml` at boot: it pins the relay address to the public IP that `talk_hostname` resolves to (the in-container interface is RFC1918 and unreachable from clients) and clamps the relay port range to exactly what we publish. Both edits re-apply on every restart and are idempotent.
- E2E call encryption is disabled in the spreed config — the server middleware otherwise enforces min-client-version 99.0.0 and rejects every current Android/iOS Talk build with HTTP 426. Flip back on once the mobile apps catch up.
