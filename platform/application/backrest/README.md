# backrest

Backrest — web UI over restic (https://github.com/garethgeorge/backrest). Single-container compose stack behind Traefik, forward-auth via Authentik (Backrest's own auth is disabled). Each instance gets its own S3 bucket + IAM principal + restic encryption password — no shared DB, no shared repo. State lives in `./data` and `./config` on the host.

**Run one instance per host being backed up.** A host compromise must not expose other hosts' snapshots. Instantiate the module N times with distinct `instance_name` values; every cloud resource (bucket `<secrets_namespace>-backrest-<instance_name>`, IAM app, secret `backrest-<instance_name>-app-secrets`, Authentik app/group, DNS, container `backrest-<instance_name>`, install dir) is namespaced by instance.

## Forward-auth wiring

Backrest's `config.json` sets `auth.disabled = true`, so the embedded forward-auth outpost guards it. The application layer binds every instance's `authentik_provider_id` into `authentik_outpost.embedded` (via `compact()` over the backrest instances, dropping nulls from disabled ones); without that the instance is reachable but the middleware returns 500. Default `authorized_groups` is `["admin"]` — Backrest exposes raw filesystem paths and a restore UI.

## Backup sources

The role bind-mounts two host trees read-only into the container under `/backup-sources/`:

| Container path | Host path | What's there |
|---|---|---|
| `/backup-sources/opt` | `/opt` | App bind-mount data (sabokit apps use `/opt/<app>`) |
| `/backup-sources/docker-volumes` | `/var/lib/docker/volumes` | Docker named volumes |

If an app writes outside both trees, **extend (don't replace)** the default via `backup_sources`; `backup_plans[].paths` then reference `/backup-sources/<new-key>/...`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname this instance is served at. |
| `instance_name` | `string` | — | Per-instance suffix that namespaces every cloud resource. Lowercase/digits/hyphens, 3-32 chars. |
| `deployment_host_key` | `string` | — | Key in `base.compute.hosts` for the host being backed up. |
| `category_group` | `string` | `"Operations"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `authorized_groups` | `list(string)` | `["admin"]` | Authentik group names allowed in. Raw paths + restore UI → admin-only by default; higher tiers nest under lower. |
| `monitoring_enabled` | `bool` | `true` | Wire `/metrics` + log paths into monitoring. |
| `image_tag` | `string` | `"latest"` | Backrest Docker image tag. Pin in production. |
| `backup_plans` | `list(object)` | `[]` | Plans rendered into `config.json`. See type signature in `variables.tf`. |
| `backup_sources` | `map(string)` | `{opt = "/opt", docker-volumes = "/var/lib/docker/volumes"}` | Host paths bind-mounted RO under `/backup-sources/<key>`. Extend; don't replace. |
| `restic_prune_max_frequency_days` | `number` | `7` | Minimum days between restic prune runs. |
| `restic_check_max_frequency_days` | `number` | `30` | Minimum days between restic repo integrity checks. |
| `restic_check_read_data_subset_percent` | `number` | `5` | Percent of pack files restic reads back during a scheduled check. 0 = metadata only. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | Proxy-provider ID; pass to identity's `extra_forward_auth_provider_ids`. |
| `authentik_application_group_id` | Per-instance group `app-backrest-<instance_name>`. |
| `monitoring` | Scrape config for `/metrics`, log paths for the container. |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `instance_name` | Echoes back `var.instance_name`. |
| `bucket_name` | Name of the S3 bucket holding this instance's restic repo. |

## Notes

- **Restic password has no recovery path.** The 48-char password is generated once and pinned (`ignore_changes = all`); losing it bricks every snapshot in the bucket. To rotate intentionally: `restic key add` via the Backrest UI first (stores the new key inside the repo), then taint `random_password.restic[0]` and re-apply, then verify before removing the old key.
- Same caveat for the IAM API key — rotating requires updating the secret version AND restarting the container so it picks up new credentials.
- On disable, Terraform tears down Authentik/DNS/IAM. **The S3 bucket and Scaleway secret are intentionally kept** — restic data is irreplaceable. Delete them manually from the Scaleway dashboard once you're sure.
