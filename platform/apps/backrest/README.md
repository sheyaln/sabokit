# apps/backrest

Backrest — web UI over restic for self-hosted backups (https://github.com/garethgeorge/backrest). Self-contained bundle:

- Authentik proxy-provider + application + per-app group (forward-auth; Backrest's own auth is disabled)
- DNS A record on the consumer's base domain
- Per-instance Scaleway S3 bucket + IAM application + API key (restic repository)
- Scaleway secret holding the restic encryption password + S3 credentials
- Ansible role that deploys a single-container compose stack behind Traefik

No database. State lives in `./data` and `./config` on the host.

## Multi-instance pattern

Most consumers run **one Backrest instance per host being backed up** — each host needs its own restic repository so a host compromise doesn't expose every other host's snapshots. The bundle is built for this: instantiate the module N times with different `instance_name` values, and every cloud resource (S3 bucket, IAM application, secret, Authentik app/group, DNS record, container name, install dir) is namespaced by the instance so they don't collide.

```hcl
# Each call provisions a complete, isolated Backrest stack.

module "backrest_mgmt" {
  source              = "git::https://github.com/sheyaln/sabokit.git//platform/apps/backrest/terraform?ref=v2.3.0"
  enabled             = try(var.apps.backrest_mgmt.enabled, false)
  hostname            = try(var.apps.backrest_mgmt.hostname, "")
  base                = module.base
  instance_name       = "mgmt"
  deployment_host_key = "management"
  backup_plans = [
    {
      id       = "monitoring-stack"
      paths    = ["/backup-sources/opt/monitoring", "/backup-sources/docker-volumes/monitoring_grafana-data"]
      schedule = { cron = "0 2 * * *" }
      retention = { daily = 7, weekly = 4, monthly = 3 }
    },
  ]
}

module "backrest_tools" {
  source              = "git::https://github.com/sheyaln/sabokit.git//platform/apps/backrest/terraform?ref=v2.3.0"
  enabled             = try(var.apps.backrest_tools.enabled, false)
  hostname            = try(var.apps.backrest_tools.hostname, "")
  base                = module.base
  instance_name       = "tools"
  deployment_host_key = "apps"
  backup_plans = [
    {
      id       = "outline"
      paths    = ["/backup-sources/opt/outline", "/backup-sources/docker-volumes/outline_storage-data"]
      schedule = { cron = "15 3 * * *" }
      retention = { daily = 7, weekly = 4, monthly = 6 }
    },
    {
      id       = "espocrm"
      paths    = ["/backup-sources/opt/espocrm", "/backup-sources/docker-volumes/espocrm_espo_data"]
      schedule = { cron = "25 3 * * *" }
      retention = { daily = 7, weekly = 4, monthly = 6 }
    },
  ]
}

module "backrest_authentik" {
  source              = "git::https://github.com/sheyaln/sabokit.git//platform/apps/backrest/terraform?ref=v2.3.0"
  enabled             = try(var.apps.backrest_authentik.enabled, false)
  hostname            = try(var.apps.backrest_authentik.hostname, "")
  base                = module.base
  instance_name       = "authentik"
  deployment_host_key = "auth"
  backup_plans = [
    {
      id       = "authentik"
      paths    = ["/backup-sources/opt/authentik"]
      schedule = { cron = "0 4 * * *" }
      retention = { daily = 7, weekly = 4, monthly = 12 }
    },
  ]
}
```

In `terraform.tfvars`:

```hcl
apps = {
  backrest_mgmt      = { enabled = true, hostname = "backup.mgmt.example.org" }
  backrest_tools     = { enabled = true, hostname = "backup.tools.example.org" }
  backrest_authentik = { enabled = true, hostname = "backup.auth.example.org" }
}
```

Each instance gets its own URL, S3 bucket (`<secrets_namespace>-backrest-<instance_name>`), IAM principal, restic encryption password (stored in `backrest-<instance_name>-app-secrets`), and Docker container (`backrest-<instance_name>`). Two instances on the same host coexist as long as their hostnames differ — they use distinct install dirs and Traefik routers.

## Forward-auth wiring

Backrest's `config.json` sets `auth.disabled = true`. The only gate is Authentik's embedded outpost via the Traefik middleware `authentik-auth@docker`. **Every** instance's `authentik_provider_id` MUST be added to the identity module's `extra_forward_auth_provider_ids`:

```hcl
module "identity" {
  source = "..."

  extra_forward_auth_provider_ids = compact([
    module.backrest_mgmt.authentik_provider_id,
    module.backrest_tools.authentik_provider_id,
    module.backrest_authentik.authentik_provider_id,
    # other forward-auth providers go here too
  ])
}
```

`compact()` drops `null` outputs from disabled instances. Forgetting this leaves the instance reachable but the middleware returns 500.

The default `access_level` is `"admin"` — Backrest exposes raw filesystem paths and a restore UI, treat it as ops-only. Override with `access_level = "member"` or pass `extra_authorized_groups` if you need broader access.

## Restic password — read this before tainting

The bundle generates a 48-char restic encryption password and stores it in Scaleway Secret Manager. The `random_password` resource has `lifecycle { ignore_changes = all }` so re-apply never rotates it.

**There is no recovery path if you lose this password.** Every snapshot in the bucket becomes unreadable. To rotate intentionally:

1. `restic key add` against the live repo via the Backrest UI (this stores the new key inside the repo itself).
2. `terraform taint` the `random_password.restic[0]` resource and re-apply.
3. Verify restic can still read snapshots with the new password before removing the old key.

Same caveat for the IAM API key — rotating it requires updating the secret version and restarting the container so it picks up the new credentials.

## Backup sources

By default the role bind-mounts two host trees read-only into the container under `/backup-sources/`:

| Container path | Host path | What's there |
|---|---|---|
| `/backup-sources/opt` | `/opt` | App bind-mount data (every sabokit app uses `/opt/<app>`) |
| `/backup-sources/docker-volumes` | `/var/lib/docker/volumes` | Docker named volumes |

Together these cover everything sabokit apps persist. If an app on the host writes outside both trees, extend (don't replace) the default via `backup_sources`:

```hcl
backup_sources = {
  opt            = "/opt"
  docker-volumes = "/var/lib/docker/volumes"
  custom-store   = "/srv/custom-app/data"
}
```

`backup_plans[].paths` then reference `/backup-sources/custom-store/...`.

## Usage

In `site.yml`, one `import_playbook` per instance, each with overrides:

```yaml
- import_playbook: ../apps/backrest/ansible/playbook.yml
  vars:
    backrest_host_group: "{{ backrest_mgmt_ansible.host_group }}"
    backrest_instance_name: "{{ backrest_mgmt_ansible.vars.backrest_instance_name }}"
    backrest_hostname: "{{ backrest_mgmt_ansible.vars.backrest_hostname }}"
    backrest_app_secret_id: "{{ backrest_mgmt_ansible.vars.backrest_app_secret_id }}"
    backrest_backup_plans: "{{ backrest_mgmt_ansible.vars.backrest_backup_plans }}"
    backrest_backup_sources: "{{ backrest_mgmt_ansible.vars.backrest_backup_sources }}"
```

(See `consumer-template/` for the wiring helpers that thread Terraform outputs into Ansible vars cleanly.)

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. When false the bundle provisions zero resources. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname this instance is served at. |
| `instance_name` | `string` | — | Per-instance suffix that namespaces every cloud resource. Lowercase/digits/hyphens, 3-32 chars. |
| `deployment_host_key` | `string` | — | Key in `base.compute.hosts` for the host being backed up. |
| `category_group` | `string` | `"Operations"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"admin"` | Key in `base.authentik.groups` granting baseline access. Backrest is ops-only by default. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | If true and a monitoring app is enabled, `/metrics` + log paths wire up. |
| `image_tag` | `string` | `"latest"` | Backrest Docker image tag. Pin in production. |
| `backup_plans` | `list(object)` | `[]` | Backup plans rendered into Backrest's `config.json`. See type signature in `variables.tf` and the multi-instance example above. |
| `backup_sources` | `map(string)` | `{opt = "/opt", docker-volumes = "/var/lib/docker/volumes"}` | Host paths bind-mounted read-only under `/backup-sources/<key>`. Extend; don't replace. |
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
| `monitoring` | Contribution map. Scrape config for `/metrics`, log paths for the container. |
| `ansible` | `{role_path, playbook, host_group, vars}` consumed by site.yml. |
| `instance_name` | Echoes back `var.instance_name`. |
| `bucket_name` | Name of the S3 bucket holding this instance's restic repo. |

## Disabling

Set `apps.backrest_<instance>.enabled = false`, then `terraform apply`. Authentik resources, DNS record, IAM principal, and consumer-side outpost binding all go away.

**The S3 bucket and Scaleway secret remain** unless removed manually — restic data is irreplaceable and deleting the bucket on a misclick would be unrecoverable. Empty the bucket and delete it from the Scaleway dashboard once you're sure no restores are needed.

The container on the host needs explicit `docker compose down` from a cleanup step (Ansible doesn't auto-undeploy).
