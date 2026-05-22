# apps/outline

Outline — the Markdown-first knowledge base. Self-contained bundle:

- Authentik OIDC provider + application + per-app group
- DNS A record on the consumer's base domain
- S3 bucket + IAM credentials for attachments
- PostgreSQL database + user inside `platform/base/terraform/`'s shared instance
- Scaleway-managed secrets bag (OIDC client secret, app SECRET_KEY, S3 keys)
- Ansible role that deploys Outline + Redis as a docker-compose stack with Traefik routing

This is the reference app bundle — the one ARCHITECTURE.md documents as the worked example.

## Usage

```hcl
module "outline" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/outline/terraform?ref=v1.0.0"
  enabled  = try(var.apps.outline.enabled, false)
  hostname = try(var.apps.outline.hostname, "")
  base     = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  outline = {
    enabled  = true
    hostname = "wiki.example.org"
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/outline/ansible/playbook.yml
  vars:
    outline_host_group: apps
    outline_hostname: "wiki.example.org"
    outline_app_secret_id: "{{ outline_terraform_outputs.ansible.vars.outline_app_secret_id }}"
    outline_db_credentials_secret_id: "{{ outline_terraform_outputs.ansible.vars.outline_db_credentials_secret_id }}"
```

(The cleanest pattern is to drop the Terraform `module.outline.ansible.vars` map into a Jinja `vars_files:` JSON, then the playbook reads them; see `consumer-template/`.)

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. When false the bundle provisions zero resources. |
| `base` | object | — | Outputs from `module.base`. Apps consume `{scaleway, authentik, compute, domains}`. |
| `hostname` | `string` | — (required when enabled) | Full hostname Outline is served at. |
| `category_group` | `string` | `"Knowledge"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups allowed beyond `access_level`. Keys are static role names (e.g. `delegate = base.authentik.groups["delegate"]`) so `for_each` can plan before group UUIDs exist. |
| `monitoring_enabled` | `bool` | `true` | If true and a monitoring app is enabled, dashboards/logs wire up. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` identifying the deploy target. |
| `image_tag` | `string` | `"latest"` | Outline Docker image tag. |
| `smtp_from_email` | `string` | `""` | From: address for outbound mail. Empty disables SMTP. |
| `max_upload_size_bytes` | `number` | `26214400` | Max upload size (25 MiB default). |
| `storage_bucket_acl` | `string` | `"public-read"` | ACL for the attachments bucket. Outline needs at least public-read for shared docs. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID (not bound to outpost — Outline is OIDC). |
| `authentik_application_group_id` | Per-app group `app-outline`. |
| `monitoring` | Contribution map for the monitoring aggregation in the consumer template. |
| `ansible` | `{role_path, playbook, host_group, vars}` consumed by site.yml. |
| `attachments_bucket_name` | Convenience: the S3 bucket name. |
| `database_name` | Convenience: the PostgreSQL database name. |

## What lands on the host

After `terraform apply && ansible-playbook site.yml`:

- `/opt/outline/docker-compose.yml` — managed file (mode 0644)
- `/opt/outline/.env` — managed file (mode 0600, contains plaintext secrets re-fetched from Scaleway Secret Manager on every play)
- Two Docker volumes: `outline_redis-data`, `outline_storage-data`
- A container named `outline` listening on port 3000, routed by Traefik at `wiki.example.org`

## Disabling

Set `apps.outline.enabled = false` in tfvars and `terraform apply`. Terraform destroys the Authentik resources, the DNS record, the S3 bucket, the database (⚠ data loss), and the Scaleway secrets. The compose stack on the host is **not** auto-torn-down — `ssh apps && cd /opt/outline && docker compose down -v && sudo rm -rf /opt/outline` to fully remove.

## Notes

- The OIDC redirect URI is `https://<hostname>/auth/oidc.callback` (Outline's convention).
- The S3 bucket name is `<base.scaleway.secrets_namespace>-outline-attachments` and must be globally unique. If you hit a collision, change `base.org_slug` or set `apps.outline.hostname` after first picking a unique bucket name elsewhere.
- Outline does NOT expose Prometheus metrics. The `monitoring` output ships only Loki log paths and a Traefik dashboard for router-level metrics.
