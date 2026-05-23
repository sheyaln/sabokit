# apps/espocrm

EspoCRM — open-source PHP CRM for tracking customers, members, donors, or any
other constituent relationship. Self-contained bundle:

- Authentik OIDC provider + application + per-app group
- DNS A record on the consumer's base domain
- PostgreSQL database + user inside `platform/base/terraform/`'s shared instance
- Scaleway-managed secrets bag (admin fallback password, OIDC bag, SMTP from-address)
- Ansible role that deploys EspoCRM + its cron daemon as a docker-compose stack with Traefik routing
- Post-deploy PHP bootstrap that wires OIDC, optional membership entities, and optional webhooks

EspoCRM keeps everything in postgres + the container's data volume. No S3, no redis.

## Usage

```hcl
module "espocrm" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/espocrm/terraform?ref=v2.1.0"
  enabled  = try(var.apps.espocrm.enabled, false)
  hostname = try(var.apps.espocrm.hostname, "")
  base     = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  espocrm = {
    enabled  = true
    hostname = "crm.example.org"
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/espocrm/ansible/playbook.yml
```

Ansible vars come from the Terraform module's `ansible.vars` output — `consumer-template/` wires this into a JSON file the playbook reads via `-e @.ansible-vars.json`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. When false the bundle provisions zero resources. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname EspoCRM is served at. |
| `category_group` | `string` | `"Tools"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | If true and a monitoring app is enabled, log paths wire up. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` identifying the deploy target. |
| `image_tag` | `string` | `"latest"` | EspoCRM Docker image tag. |
| `timezone` | `string` | `"UTC"` | IANA timezone for the container and the app's runtime config. |
| `admin_username` | `string` | `"admin"` | Local admin username (break-glass account; OIDC is the primary path). |
| `b2c_mode` | `bool` | `true` | Enable EspoCRM's "Business to Consumer" mode (simpler UI; hides Accounts). |
| `oidc_username_claim` | `string` | `"email"` | OIDC claim used as the EspoCRM username. |
| `oidc_group_claim` | `string` | `"groups"` | OIDC claim carrying group memberships. |
| `oidc_team_id_prefix` | `string` | `"sso-"` | Prefix used when auto-creating EspoCRM teams from OIDC groups. |
| `oidc_group_role_mapping` | `map(string)` | `{}` | `{ authentik_group_name: EspoCRM Role Name }`. |
| `enable_member_entity_bootstrap` | `bool` | `false` | Provisions Member + DuesPayment entities, roles, teams, and navbar. |
| `member_entity_webhooks` | `list(object)` | `[]` | Webhook definitions to upsert; see [Webhooks](#webhooks). |
| `smtp_from_email` | `string` | `""` | From-address for outbound mail. Empty disables SMTP. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | OIDC provider ID. |
| `authentik_application_group_id` | Per-app group `app-espocrm`. |
| `monitoring` | Contribution map for the monitoring aggregation. |
| `ansible` | `{role_path, playbook, host_group, vars}` consumed by site.yml. |
| `database_name` | PostgreSQL database name. |

## What lands on the host

After `terraform apply && ansible-playbook site.yml`:

- `/opt/espocrm/docker-compose.yml` — managed file (mode 0644)
- `/opt/espocrm/.env` — managed file (mode 0600, regenerated from Scaleway Secret Manager on every play)
- `/opt/espocrm/configure-*.php` — rendered bootstrap scripts; `docker cp`'d into the container and executed
- Two containers: `espocrm` (PHP on port 80, routed by Traefik) and `espocrm-daemon` (cron-equivalent)
- A named docker volume `espocrm-data` holding the application files and `data/config.php`. **Back this up.**

## Bootstrap scripts

The role runs three PHP scripts inside the container after the stack is healthy:

| Script | Always | What it does |
|--------|--------|--------------|
| `configure-oidc.php` | Yes | Writes OIDC + system config into `data/config.php`, and (optionally) joins `oidc_group_role_mapping` against the `role` table. |
| `configure-member-entity.php` | When `enable_member_entity_bootstrap = true` | Creates the `Member` and `DuesPayment` custom entities, four default roles, four matching teams, navbar layout, and hides the default sales-CRM entities (Account, Lead, Contact, etc.). |
| `configure-webhooks.php` | When `member_entity_webhooks` is non-empty | Upserts the supplied webhook rows directly against the `webhook` table. |

EspoCRM doesn't expose REST API endpoints for the keys the OIDC bootstrap
touches before an admin signs in, so the file-edit-then-rebuild path is the
one that works on a fresh install. The bootstrap is idempotent: re-running it
overwrites the OIDC config keys and upserts the roles/teams/webhooks, leaving
fields it doesn't manage alone.

## Member-entity bootstrap (opt-in)

When `enable_member_entity_bootstrap = true`:

- Creates the `Member` entity (firstName, lastName, memberId, address, membershipStatus, duesTier, paidUpThrough, recurringDues, …)
- Creates the `DuesPayment` entity linked back to `Member` (amount, paymentDate, method, coversUntil, receiptNumber)
- Creates roles `Member Admin`, `Member Steward`, `Member Viewer`, `Dues Treasurer` with sensible read/edit/delete defaults
- Creates teams of the same names, linked to the matching role
- Configures the navbar to surface a single `Membership` group with `Members` and `Dues Payments`
- Hides EspoCRM's default sales-CRM entities (`Account`, `Lead`, `Contact`, `Opportunity`, `Case`, `Campaign`, `TargetList`, `Target`, `Document`, `DocumentFolder`)
- Sets a field-level ACL so `streetAddress` and `postalCode` are hidden from the `Member Viewer` role

Leave this off (the default) if you want EspoCRM as a generic sales CRM with
Accounts/Leads/Opportunities.

### Wiring SSO groups to roles

Combine with `oidc_group_role_mapping` to drive role assignment from
Authentik group membership:

```hcl
module "espocrm" {
  # ...
  enable_member_entity_bootstrap = true
  oidc_group_role_mapping = {
    "admin"            = "Member Admin"
    "membership-team"  = "Member Steward"
    "finance"          = "Dues Treasurer"
  }
}
```

The OIDC bootstrap joins these against the `role` table by name and writes
the resolved IDs into `oidcGroupRoleMapping` in `data/config.php`. Roles
referenced here must already exist — either built-in, provisioned by the
member-entity bootstrap, or hand-created in the Admin UI.

## Webhooks

`member_entity_webhooks` accepts a list of webhook objects. Typical use is
pointing EspoCRM at an internal automation service (e.g. n8n) so business
events flow into the wider stack:

```hcl
member_entity_webhooks = [
  {
    id    = "member-created"
    name  = "New member notification"
    event = "afterSave"
    type  = "create"
    field = null
    url   = "https://n8n.example.org/webhook/espocrm-new-member"
  },
]
```

Defaults to `[]` (no webhooks). The bootstrap upserts on the supplied `id`
so re-applies are safe.

## Disabling

Set `apps.espocrm.enabled = false` in tfvars and `terraform apply`. Terraform
destroys the Authentik resources, the DNS record, the database (⚠ data
loss), and the Scaleway secret. The compose stack and the `espocrm-data`
volume on the host are **not** auto-torn-down — `ssh apps && cd /opt/espocrm
&& docker compose down -v && sudo rm -rf /opt/espocrm` to fully remove.

## Notes

- The local admin fallback (`admin` by default) is the break-glass account.
  Its password lives in the Scaleway secret bag and has `ignore_changes = all`
  upstream — regenerating in Terraform would diverge from the in-DB value.
  Rotate by tainting `random_password.admin` and the in-database `users`
  row in concert.
- EspoCRM's daemon container runs the scheduled-job worker. Without it,
  reminders, notifications, and **webhook delivery** stall — the daemon is
  the only thing that drains the webhook queue.
- The OIDC redirect URI is `https://<hostname>/oauth-callback.php`; register
  exactly this in the OIDC provider config (the bundle does it automatically
  via `modules/authentik/oidc-app`).
- B2C mode (`b2c_mode = true`, default) hides company/account fields in the
  Member detail view. Flip to `false` for traditional sales-CRM deployments.
