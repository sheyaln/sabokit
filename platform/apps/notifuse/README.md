# apps/notifuse

Notifuse — open-source transactional + marketing email manager. Self-contained bundle:

- Authentik OIDC provider + application + per-app group (defaults to admin-only access; notifuse is an operator tool)
- DNS A record on the consumer's base domain
- PostgreSQL database + user
- S3 bucket for marketing assets (templates, attachments)
- Scaleway-managed secrets bag with the workspace `SECRET_KEY`, root-admin credentials, OIDC + S3 config, and SMTP from-address
- Ansible role that deploys notifuse as a single container with Traefik routing

## Critical lifecycle notes

- **`SECRET_KEY` is immutable.** Notifuse encrypts every workspace secret with it. The Terraform `random_password.secret_key` has `lifecycle { ignore_changes = all }` so re-applies don't regenerate it. To genuinely rotate, taint the resource AND plan a re-encrypt of every workspace.
- **`ROOT_ADMIN_PASSWORD` is also locked** after first apply — same reason. It's the fallback login if OIDC is misconfigured.
- **`scaleway_secret_version.app` has `ignore_changes = [data]`** so peripheral fields (e.g. OIDC client_secret rotating underneath) don't churn the secret version forever. To force a re-render, taint it.

## Usage

```hcl
module "notifuse" {
  source           = "git::https://github.com/sheyaln/sabokit.git//platform/apps/notifuse/terraform?ref=v2.3.0"
  enabled          = try(var.apps.notifuse.enabled, false)
  hostname         = try(var.apps.notifuse.hostname, "")
  root_admin_email = try(var.apps.notifuse.root_admin_email, "")
  base             = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  notifuse = {
    enabled          = true
    hostname         = "email.example.org"
    root_admin_email = "ops@example.org"
    smtp_from_email  = "notify@example.org"
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/notifuse/ansible/playbook.yml
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname. |
| `root_admin_email` | `string` | — (required when enabled) | Initial root admin email. |
| `smtp_from_email` | `string` | `""` | From-address. Empty disables SMTP. |
| `category_group` | `string` | `"Productivity"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon. |
| `access_level` | `string` | `"admin"` | Defaults to admin-only — notifuse is an ops tool. |
| `extra_authorized_groups` | `map(string)` | `{}` | Extra groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | Wire log paths into monitoring. |
| `deployment_host_key` | `string` | `"apps"` | Target host. |
| `image_tag` | `string` | `"latest"` | Image tag. |
| `oidc_auto_provision` | `bool` | `true` | Auto-create user on first OIDC login. |
| `oidc_allow_magic_code` | `bool` | `true` | Allow magic-link login fallback alongside OIDC. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group. |
| `monitoring` | Contribution map (log paths only). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
| `files_bucket_name` | S3 bucket name. |
| `database_name` | PostgreSQL database. |
| `root_admin_email` | Echoed for docs; password lives in the app-secrets bag. |

## Recovering root admin access

The bootstrap admin password is in the Scaleway secret printed at apply time. Pull it with `scw secret version access`:

```bash
SECRET_ID=$(terraform output -json | jq -r '.enabled_apps.value.notifuse.ansible_vars.notifuse_app_secret_id' | sed 's|.*/||')
scw secret version access secret-id="$SECRET_ID" revision=latest -o json \
  | jq -r '.data' | base64 -d | jq -r '.ROOT_ADMIN_PASSWORD'
```

Use that with `ROOT_ADMIN_EMAIL` to sign in if OIDC isn't yet working.

## Disabling

`apps.notifuse.enabled = false` + `terraform apply`. Drops Authentik resources, DNS, DB (⚠ data loss), S3 bucket, IAM key, secrets. Compose stack + `/opt/notifuse/data/` survive on the host.
