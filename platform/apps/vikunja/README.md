# apps/vikunja

Vikunja — open-source task and project tracker. Self-contained bundle:

- Authentik OIDC provider + application + per-app group
- DNS A record on the consumer's base domain
- PostgreSQL database + user inside `platform/base/terraform/`'s shared instance
- Scaleway-managed secrets bag (JWT signing key, OIDC client secret, from-email)
- Ansible role that deploys Vikunja as a single docker-compose service with Traefik routing
- Host-side bind mount at `/opt/vikunja/files` for user-uploaded attachments

No S3 bucket, no redis — Vikunja keeps everything in postgres + the filesystem volume. Switch to an S3 backend by extending `tfvars.schema` and the env template when an org needs object storage.

## Usage

```hcl
module "vikunja" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/vikunja/terraform?ref=v2.2.0"
  enabled  = try(var.apps.vikunja.enabled, false)
  hostname = try(var.apps.vikunja.hostname, "")
  base     = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  vikunja = {
    enabled  = true
    hostname = "tasks.example.org"
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/vikunja/ansible/playbook.yml
```

Ansible vars come from the Terraform module's `ansible.vars` output — `consumer-template/` wires this into a JSON file the playbook reads via `-e @.ansible-vars.json`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. When false the bundle provisions zero resources. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname Vikunja is served at. |
| `category_group` | `string` | `"Productivity"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | If true and a monitoring app is enabled, log paths wire up. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` identifying the deploy target. |
| `image_tag` | `string` | `"latest"` | Vikunja Docker image tag. |
| `timezone` | `string` | `"UTC"` | Server timezone (IANA). Affects reminders and recurring-task next-run. |
| `enable_registration` | `bool` | `false` | Vikunja's built-in local-account registration. Independent of OIDC. |
| `enable_local_auth` | `bool` | `false` | Whether Vikunja accepts username+password logins in addition to OIDC. |
| `smtp_from_email` | `string` | `""` | From-address for outbound mail. Empty disables SMTP. |
| `oidc_groups_scope_name` | `string` | `"vikunja_scope"` | Authentik custom-scope name carrying the `vikunja_groups` team-assignment claim. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-vikunja`. |
| `monitoring` | Contribution map for the monitoring aggregation. |
| `ansible` | `{role_path, playbook, host_group, vars}` consumed by site.yml. |
| `database_name` | PostgreSQL database name. |

## What lands on the host

After `terraform apply && ansible-playbook site.yml`:

- `/opt/vikunja/docker-compose.yml` — managed file (mode 0644)
- `/opt/vikunja/.env` — managed file (mode 0600, plaintext secrets re-fetched from Scaleway Secret Manager on every play)
- `/opt/vikunja/files/` — bind mount, mode 0750, holds attachments. **Back this up.** It's not in postgres.
- A container named `vikunja` listening on port 3456, routed by Traefik at `tasks.example.org`

## Disabling

Set `apps.vikunja.enabled = false` in tfvars and `terraform apply`. Terraform destroys the Authentik resources, the DNS record, the database (⚠ data loss), and the Scaleway secret. The compose stack and the `/opt/vikunja/files/` directory on the host are **not** auto-torn-down — `ssh apps && cd /opt/vikunja && docker compose down -v && sudo rm -rf /opt/vikunja` to fully remove.

## Notes

- OIDC redirect URI is `https://<hostname>/auth/openid/authentik` (Vikunja's convention for the provider named `authentik`).
- The `vikunja_scope` OIDC scope is what Vikunja reads team-assignment data from. The scope itself isn't created by this bundle — define it as a custom scope on the Authentik admin side and attach a `vikunja_groups` mapping that emits the user's group memberships under that scope's claim. Without that scope existing, OIDC login still works; team auto-assignment doesn't.
- Vikunja's API is at `/api/v1/`; the bundle leaves it under the same Traefik router as the web UI.
