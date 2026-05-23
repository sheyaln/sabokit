# apps/nextcloud

Nextcloud — files, calendar, contacts. Self-contained bundle:

- Authentik OIDC provider + application + per-app group
- DNS A record on the consumer's base domain
- PostgreSQL database + user
- S3 bucket for primary storage (all user files live there, not on the host disk)
- Scaleway-managed secrets bag (bootstrap admin password, Redis password, OIDC + S3 config, SMTP from-address)
- Ansible role that deploys Nextcloud + Redis + cron as a docker-compose stack with Traefik routing, then runs an idempotent `occ` script to wire up Redis, OIDC, trusted_proxies, and Scaleway-S3 integrity flags

## Critical lifecycle notes

- **`NEXTCLOUD_ADMIN_PASSWORD` is immutable.** Nextcloud reads it once on first install to seed the admin user. Rotating in Terraform does not rotate the in-DB password. The `random_password.admin` resource has `lifecycle { ignore_changes = all }`. To rotate, change it through the Nextcloud admin UI then taint the resource.
- **`REDIS_PASSWORD` is also locked** after first apply. Rotating mid-flight orphans existing locks. To rotate, taint the resource and restart the stack (`docker compose down && up`).
- **`scaleway_secret_version.app` has `ignore_changes = [data]`** so peripheral fields (e.g. OIDC client_secret rotating underneath) don't churn the secret version forever. To force a re-render, taint it.
- **Image tag pinning.** Default is `32-apache`. Nextcloud only supports one-major-at-a-time upgrades; bumping the tag from `32-apache` to `34-apache` will fail. Step through each major (`32` → `33` → `34`) and let the upgrade complete between bumps.

## Usage

```hcl
module "nextcloud" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/nextcloud/terraform?ref=v2.2.0"
  enabled  = try(var.apps.nextcloud.enabled, false)
  hostname = try(var.apps.nextcloud.hostname, "")
  base     = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  nextcloud = {
    enabled         = true
    hostname        = "cloud.example.org"
    smtp_from_email = "cloud@example.org"  # optional
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
| `category_group` | `string` | `"Files"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups allowed beyond `access_level`. Keys are static role names. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image_tag` | `string` | `"32-apache"` | Image tag. Pin to a major. |
| `admin_username` | `string` | `"ncadmin"` | Bootstrap admin username. |
| `default_phone_region` | `string` | `"US"` | ISO 3166-1 alpha-2 region for phone-number formatting. |
| `max_upload_size_bytes` | `number` | `2147483648` | 2 GiB. Apache body limit tracks this. |
| `trusted_proxies` | `string` | `"172.16.0.0/12"` | CIDR trusted as reverse proxy (default covers Docker bridge). |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |

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
- `/opt/nextcloud/configure-nextcloud.sh` — idempotent post-install occ wiring (Redis, OIDC, trusted_proxies, S3 integrity flags, SMTP)
- Docker volumes: `nextcloud_redis-data`, `nextcloud_nextcloud-data`, `nextcloud_nextcloud-fontcache`, `nextcloud_nextcloud-wwwcache`
- Three containers: `nextcloud-app` (port 80, routed by Traefik), `nextcloud-redis`, `nextcloud-cron`

User files live in the S3 bucket, not on the host. The local `nextcloud-data` volume only holds Nextcloud's PHP installation, apps, and metadata.

## Recovering admin access

The bootstrap admin password is in the Scaleway secret. Pull it with `scw secret version access`:

```bash
SECRET_ID=$(terraform output -json | jq -r '.enabled_apps.value.nextcloud.ansible_vars.nextcloud_app_secret_id' | sed 's|.*/||')
scw secret version access secret-id="$SECRET_ID" revision=latest -o json \
  | jq -r '.data' | base64 -d | jq -r '.NEXTCLOUD_ADMIN_PASSWORD'
```

Use that with `NEXTCLOUD_ADMIN_USER` (default `ncadmin`) to sign in if OIDC isn't yet working. Once OIDC is verified, set a long random password through the admin UI and stop using the bootstrap account.

## Disabling

`apps.nextcloud.enabled = false` + `terraform apply`. Terraform destroys the Authentik resources, DNS record, S3 bucket (⚠ all user files lost), database (⚠ all metadata lost), and secrets. The compose stack on the host is **not** auto-torn-down — `ssh apps && cd /opt/nextcloud && docker compose down -v && sudo rm -rf /opt/nextcloud`.

## Notes

- The OIDC redirect URI is `https://<hostname>/apps/user_oidc/code` (Nextcloud's `user_oidc` app convention).
- The S3 bucket name is `<base.scaleway.secrets_namespace>-nextcloud-data` and must be globally unique across all Scaleway customers.
- `OBJECTSTORE_S3_USEPATH_STYLE=false` because Scaleway supports virtual-hosted-style buckets and path-style triggers redirects.
- The configure script sets `request_checksum_calculation=when_required` to work around Scaleway's CRC32 trailing-checksum rejection on Nextcloud 32+.
- The configure script sets `allow_local_remote_servers=true` so OIDC + federation calls work when public hostnames resolve to VPC private IPs (split-horizon DNS); remove this if your VPC doesn't use split-horizon.

## Companions (separate bundles)

The legacy DCIWW Ansible role bundled three extra services with Nextcloud. They are deferred to their own bundles:

- **OnlyOffice document server** — separate `apps/onlyoffice/` bundle. The configure script does not enable the `onlyoffice` Nextcloud app; when both bundles are deployed, register OnlyOffice via Admin → OnlyOffice in the Nextcloud UI (or add a cross-app integration TF file).
- **Talk HPB (TURN/STUN + signaling)** — separate `apps/nextcloud-talk-hpb/` bundle. Nextcloud Talk itself works without HPB for small calls; HPB only kicks in beyond ~5 participants.
- **n8n form-submission webhook** — cross-app integration. Belongs in `apps/n8n/terraform/integrations/nextcloud.tf` once both bundles are deployed together.
