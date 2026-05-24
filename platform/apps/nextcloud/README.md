# apps/nextcloud

Nextcloud + OnlyOffice Document Server + Talk HPB as one bundle: five containers, three hostnames, one docker-compose stack. Primary file storage is S3; PostgreSQL is the shared instance.

Nextcloud only supports one-major-at-a-time upgrades. Step through majors (`32` → `33` → `34`); don't jump.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname Nextcloud is served at. |
| `onlyoffice_hostname` | `string` | — (required when enabled) | Full hostname OnlyOffice Document Server is served at. |
| `talk_hostname` | `string` | — (required when enabled) | Full hostname Talk HPB signaling (WSS) is served at. Same DNS name also resolves to TURN on UDP/TCP 3478. |
| `category_group` | `string` | `"Files"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image_tag` | `string` | `"32-apache"` | Nextcloud image tag. Pin to a major. |
| `admin_username` | `string` | `"ncadmin"` | Bootstrap admin username. |
| `instance_name` | `string` | `"Nextcloud"` | User-facing instance name (browser tab, mail headers, mobile clients). |
| `maintenance_window_start` | `number` | `2` | UTC hour for nightly background-job window. |
| `enabled_apps` | `list(string)` | groupfolders/notify_push/notes/tasks/forms/polls/epubviewer/webhook_listeners | Apps the post-install script auto-installs + enables every run. |
| `disabled_apps` | `list(string)` | `["photos"]` | Apps the post-install script disables every run. |
| `n8n_form_webhook_url` | `string` | `""` | Optional. Registers a `webhook_listeners` hook for `OCA\Forms\Events\FormSubmittedEvent` pointed at this URL. Requires `webhook_listeners` in `enabled_apps`. |
| `default_phone_region` | `string` | `"US"` | ISO 3166-1 alpha-2 region for phone-number formatting. |
| `max_upload_size_bytes` | `number` | `2147483648` | 2 GiB. Apache body limit tracks this. |
| `trusted_proxies` | `string` | `"172.16.0.0/12"` | CIDR trusted as reverse proxy (covers Docker bridge by default). |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |
| `onlyoffice_image_tag` | `string` | `"latest"` | OnlyOffice Document Server image tag. |
| `onlyoffice_memory_limit` | `string` | `"2G"` | OnlyOffice memory ceiling. |
| `onlyoffice_cpu_limit` | `string` | `"2.0"` | OnlyOffice CPU ceiling. |
| `talk_image_tag` | `string` | `"latest"` | Tag for `ghcr.io/nextcloud-releases/aio-talk`. |
| `talk_turn_port` | `number` | `3478` | TCP/UDP port for eturnal TURN. Opened in the host SG automatically. |
| `talk_relay_port_min` | `number` | `49152` | Lower bound of the eturnal UDP relay range. |
| `talk_relay_port_max` | `number` | `49252` | Upper bound of the eturnal UDP relay range. |
| `talk_memory_limit` | `string` | `"1G"` | Talk HPB memory ceiling. |
| `talk_cpu_limit` | `string` | `"1.0"` | Talk HPB CPU ceiling. |

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

## Notes

- OIDC redirect URI is `https://<hostname>/apps/user_oidc/code`.
- User files live in the S3 bucket (`<secrets_namespace>-nextcloud-data`), not on the host. The local Nextcloud volume only holds the PHP install, apps, and metadata.
- Talk HPB media (TURN + UDP relay range) bypasses Traefik and binds on the host; the bundle opens the ports in the SG and patches `eturnal.yml` on each restart to advertise the public IP.
- E2E call encryption in spreed is disabled — the server middleware otherwise rejects current Talk mobile clients with HTTP 426. Re-enable once apps catch up.
- App auto-install runs on every play and is idempotent. Removing an app from `enabled_apps` does NOT uninstall it — only newly-added apps install; flip `disabled_apps` to actively turn one off.
- The post-install script also sets fixed defaults that aren't surfaced as vars (sensible for ~every consumer): preview limit 2048×2048, JPEG quality 60, distributed file locking on, versions retention `auto, 30`, activity expiry 365 days, log rotate at 100 MB. Edit `configure-nextcloud.sh` if your install needs different.
