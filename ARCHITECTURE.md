# Federated Commons Architecture

This document is the **contract** for module authors and consumers. It defines how `base/`, `apps/`, `modules/`, and `consumer-template/` fit together and what each must guarantee.

If you are adding a new app bundle, building a new base sub-module, or writing a new consumer, this is your spec.

## Table of contents

- [Layered model](#layered-model)
- [The base ↔ app contract](#the-base--app-contract)
  - [What `base/` outputs](#what-base-outputs)
  - [What every app bundle consumes](#what-every-app-bundle-consumes)
  - [What every app bundle exports](#what-every-app-bundle-exports)
- [App bundle layout](#app-bundle-layout)
- [The enable/disable mechanism](#the-enabledisable-mechanism)
- [Monitoring contribution mechanism](#monitoring-contribution-mechanism)
- [Cross-app integration mechanism](#cross-app-integration-mechanism)
- [Outpost binding mechanism](#outpost-binding-mechanism)
- [Naming and variable conventions](#naming-and-variable-conventions)
- [Versioning](#versioning)
- [Worked example: Outline](#worked-example-outline)

---

## Layered model

```
modules/             # Low-level Terraform primitives. No application semantics.
                     # Reusable building blocks: network, compute, postgres,
                     # object_bucket, secrets, app_dns, oidc-app, saml-app, etc.

base/                # The platform every consumer needs once.
                     # Composes modules/ into a runnable Authentik instance,
                     # a Scaleway project layout, and a set of bootstrap
                     # Ansible roles (docker, traefik, fail2ban, ...).

apps/<name>/         # One self-contained bundle per app. Owns its Authentik
                     # OIDC/SAML resources, its DNS records, its S3 bucket,
                     # its database, its secrets, its monitoring artifacts,
                     # and its Ansible deploy role. Inert when disabled.

consumer-template/   # The starter a new org copies. Calls base/ once and
                     # calls platform/apps/<name>/ as many times as the org needs.
                     # Holds tfvars, inventory.ini, and site.yml.
```

**Dependency direction**: `consumer-template` → `base` and `apps/*`. `apps/*` → `base` (via consumer-passed outputs) and `modules/*`. `base` → `modules/*`. `modules/*` depends on nothing in this tree.

Apps never depend on each other directly. Cross-app coupling lives in `platform/apps/<name>/integrations/<other-app>.tf` and is gated by a toggle that only fires if both apps are enabled.

---

## The base ↔ app contract

### What `base/` outputs

`base/` is the contract surface for every app. Every output here is stable across patch and minor releases. Breaking these is a major version bump.

The contract is split by concern:

```hcl
# From platform/base/terraform/outputs.tf
output "scaleway" {
  description = "Scaleway platform handles. Apps use these to provision their own resources."
  value = {
    project_id           = string
    region               = string
    zone                 = string
    vpc_id               = string
    private_network_id   = string
    dns_zone             = string  # e.g. "example.org"
    postgres_instance_id = string
    postgres_endpoint    = object({ ip = string, port = number })
    postgres_admin_user  = string
    postgres_admin_password_secret_id = string  # Scaleway Secret Manager ID
    object_storage_endpoint = string
    secrets_namespace    = string  # Scaleway secrets path prefix, e.g. "fc-prod/"
  }
}

output "compute" {
  description = "Compute hosts apps can target via Ansible."
  value = {
    hosts = map(object({
      id           = string
      public_ip    = string
      private_ip   = string
      ansible_group = string  # e.g. "tools", "management"
      role         = string  # what this host is intended for: "apps", "monitoring", "auth"
    }))
  }
}

# From platform/identity/terraform/outputs.tf
output "authentik" {
  description = "Authentik platform handles. Apps use these to register OIDC/SAML/proxy providers."
  value = {
    api_url              = string  # for the provider block
    api_token_secret_id  = string  # Scaleway Secret Manager ID
    gateway_domain       = string  # e.g. "auth.example.org"
    org_name             = string
    flows = object({
      authentication_flow      = string  # UUID
      authorization_flow       = string  # UUID
      invalidation_flow        = string  # UUID
      password_reset_flow      = string  # UUID
      user_settings_flow       = string  # UUID
      unenrollment_flow        = string  # UUID
      source_authentication_flow = string  # UUID
      source_enrollment_flow     = string  # UUID
    })
    groups = map(string)  # base group name -> Authentik group ID
                          # always contains: admin, member
                          # optional defaults: delegate, treasurer
                          # consumer adds via base var.extra_groups
    sources = map(string) # social source slug -> UUID (e.g. "google", "apple"); may be {}
    outpost_id          = string  # embedded outpost
    branding_assets_path = string  # filesystem path consumed by ansible
  }
}

# From base/domains/outputs.tf (or merged into scaleway)
output "domains" {
  description = "Domains the consumer manages."
  value = {
    base_domain = string  # e.g. "example.org"
    mgmt_domain = string  # e.g. "ops.example.org"; may equal base_domain
  }
}
```

**Why a single `outputs.base` map per concern, not flat outputs?**

Apps consume `var.base` as one object. Adding a field to `base` requires no consumer-side change. Removing a field is breaking. This makes the contract diffable in one place and lets apps `var.base.authentik.flows.authentication_flow` rather than juggling a dozen flat inputs.

### What every app bundle consumes

Every app bundle MUST declare these inputs in `platform/apps/<name>/variables.tf`:

```hcl
variable "enabled" {
  description = "Master toggle. When false, the app provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from the base module. Pass-through from the consumer's module.base."
  type        = any  # cannot be strictly typed because Terraform doesn't allow
                     # forward references at module boundary; document the shape
                     # in the README and rely on plan-time errors.
}

variable "hostname" {
  description = "Full hostname this app is served at. NEVER assembled from a subdomain prefix inside the module."
  type        = string
  # Required (no default). Consumer always passes e.g. "wiki.example.org".
}

variable "category_group" {
  description = "Authentik application category. Free text shown in the user-portal grid."
  type        = string
  default     = "Tools"
}

variable "icon_url" {
  description = "Path or URL to the app's icon in Authentik media. Optional."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Required role to access this app. Must be a key in base.authentik.groups (e.g. \"admin\", \"member\")."
  type        = string
  default     = "member"
  # No validation enum — base provides the group taxonomy, apps reference it.
}

variable "extra_authorized_groups" {
  description = "Additional Authentik group IDs allowed to access this app beyond the access_level chain."
  type        = list(string)
  default     = []
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, this app's metrics/dashboards/logs are wired up."
  type        = bool
  default     = true
}
```

An app MAY declare additional inputs for its own specifics (e.g. `outline_smtp_from_address`). Always namespaced by the app slug.

### What every app bundle exports

Every app bundle MUST export these outputs in `platform/apps/<name>/outputs.tf`:

```hcl
output "enabled" {
  description = "Whether this app is enabled."
  value       = var.enabled
}

output "app_url" {
  description = "Where the app is reachable. https://<hostname>."
  value       = var.enabled ? "https://${var.hostname}" : null
}

output "authentik_provider_id" {
  description = "Provider ID for outpost binding. null if not a forward-auth app."
  value       = var.enabled ? try(<provider>.id, null) : null
}

output "authentik_application_group_id" {
  description = "ID of the per-app Authentik group. null when disabled."
  value       = var.enabled ? <group>.id : null
}

output "monitoring" {
  description = "Monitoring contribution. Consumed by monitoring apps when both are enabled."
  value = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = list(any)  # rendered scrape config blocks
    grafana_dashboards        = list(string)  # absolute paths to dashboard JSON files
    loki_log_paths            = list(string)  # filesystem globs the loki shipper should tail
    alert_rules               = list(any)     # rendered alerting rule blocks
  } : null
}

output "ansible" {
  description = "Ansible deployment metadata. Consumed by the consumer's site.yml."
  value = var.enabled ? {
    role_path   = "${path.module}/ansible/role"
    playbook    = "${path.module}/ansible/playbook.yml"
    host_group  = string  # which ansible inventory group this app deploys to
    vars        = map(any)  # role variables the consumer should set on the host
  } : null
}
```

The `null when disabled` pattern is load-bearing. Consumers and other apps use `coalesce(module.outline.monitoring, {})` patterns to drop disabled apps from aggregation.

---

## App bundle layout

Every `platform/apps/<name>/` directory follows this exact structure:

```
platform/apps/outline/
├── terraform/
│   ├── versions.tf          # Required providers (scaleway, authentik, random)
│   ├── variables.tf         # The contract inputs above, plus app-specific ones
│   ├── outputs.tf           # The contract outputs above
│   ├── locals.tf            # Computed values (e.g. derived hostnames, normalized config)
│   ├── authentik.tf         # OIDC/SAML/proxy provider, application, per-app group, policy bindings
│   ├── dns.tf               # A/AAAA/CNAME records (NEVER assembles subdomains)
│   ├── storage.tf           # S3 bucket (omit file if app has no object storage)
│   ├── database.tf          # rdb_database + rdb_user in base.scaleway.postgres_instance (omit if no DB)
│   ├── secrets.tf           # App-specific Scaleway secrets (OIDC client secret, app SECRET_KEY, DB URL)
│   ├── monitoring.tf        # Defines the monitoring output (scrape config, dashboards, alerts)
│   └── integrations/        # Optional per-other-app integration files; each gated by its own var
│       └── <other-app>.tf
├── ansible/
│   ├── role/                # An Ansible role: tasks/, templates/, defaults/, handlers/, vars/, meta/
│   │   ├── tasks/main.yml
│   │   ├── templates/
│   │   │   ├── docker-compose.yml.j2
│   │   │   └── env.j2
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml
│   │   └── meta/main.yml     # Declares dependencies on base roles (docker, traefik)
│   └── playbook.yml          # `import_playbook`-able from consumer site.yml. Targets the host group.
├── monitoring/
│   ├── dashboards/           # Grafana dashboard JSON files (literal exported dashboards)
│   ├── scrape.yml.tpl        # Prometheus scrape config snippet template
│   └── alerts.yml.tpl        # Prometheus alerting rules template
└── README.md                 # Spec: inputs, outputs, what this app brings, what integrations exist
```

Files in `terraform/` may be omitted when not applicable (a static app may have no `database.tf`). Files in `monitoring/` may be empty stubs when the app exposes no metrics. The `ansible/` directory is required for every app (no terraform-only apps in this design — if you only need Authentik config, write a `bookmark` app or extend `base/`).

---

## The enable/disable mechanism

A consumer's `terraform.tfvars` declares which apps are on:

```hcl
apps = {
  outline = {
    enabled  = true
    hostname = "wiki.example.org"
  }
  nextcloud = {
    enabled  = true
    hostname = "cloud.example.org"
  }
  jitsi = {
    enabled = false
  }
  # ... every app has an entry, default disabled
}
```

The consumer's `apps.tf` reads `var.apps` and passes per-app config to each module:

```hcl
module "outline" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/outline/terraform?ref=v2.1.0"
  enabled  = try(var.apps.outline.enabled, false)
  hostname = try(var.apps.outline.hostname, "")
  base     = module.base
}
```

Inside the app, every resource is gated:

```hcl
resource "authentik_provider_oauth2" "this" {
  count = var.enabled ? 1 : 0
  # ...
}
```

`count = var.enabled ? 1 : 0` is the only acceptable disable pattern. Do not gate at the module-call level by `for_each = var.enabled ? toset(["x"]) : toset([])` — the address `module.outline[\"x\"]` is annoying for state moves and consumers.

When `enabled = false`, the module evaluates but produces zero resources. The plan is empty for that app. Switching `enabled = true` later creates everything fresh. Switching back to `false` destroys cleanly.

---

## Monitoring contribution mechanism

Every app declares its monitoring artifacts whether or not monitoring is enabled. The contract output is `monitoring`. Monitoring apps (`apps/prometheus`, `apps/grafana`, `apps/loki`) read the union of all enabled apps' monitoring outputs at the consumer level.

### Inside an app: `monitoring.tf`

```hcl
# platform/apps/outline/terraform/monitoring.tf
output "monitoring" {
  description = "Monitoring contribution. null when disabled or opted out."
  value = (var.enabled && var.monitoring_enabled) ? {
    prometheus_scrape_configs = [
      {
        job_name        = "outline"
        scheme          = "http"
        metrics_path    = "/metrics"
        static_configs  = [{ targets = ["${var.hostname}:9090"] }]
      }
    ]
    grafana_dashboards = [
      "${path.module}/../monitoring/dashboards/outline-overview.json",
    ]
    loki_log_paths = [
      "/var/log/containers/outline-*.log",
    ]
    alert_rules = []
  } : null
}
```

### In the consumer: aggregation

```hcl
# consumer-template/terraform/monitoring_aggregation.tf
locals {
  app_monitoring = [
    module.outline.monitoring,
    module.nextcloud.monitoring,
    # ... every app
  ]
  enabled_monitoring = [for m in local.app_monitoring : m if m != null]

  all_scrape_configs = flatten([for m in local.enabled_monitoring : m.prometheus_scrape_configs])
  all_dashboards     = flatten([for m in local.enabled_monitoring : m.grafana_dashboards])
  all_log_paths      = flatten([for m in local.enabled_monitoring : m.loki_log_paths])
  all_alert_rules    = flatten([for m in local.enabled_monitoring : m.alert_rules])
}
```

### Monitoring apps consume the aggregate

```hcl
module "prometheus" {
  source         = "git::...//apps/prometheus/terraform?ref=v2.1.0"
  enabled        = try(var.apps.prometheus.enabled, false)
  hostname       = try(var.apps.prometheus.hostname, "")
  base           = module.base
  scrape_configs = local.all_scrape_configs
  alert_rules    = local.all_alert_rules
}
```

This pattern means:
- Disable Prometheus → app metrics are still declared but unused. No harm.
- Disable Outline → its scrape config drops out of the aggregate. Prometheus reconfigures on next apply.
- Disable Outline's monitoring opt-in → same as above but lets you keep Outline running without metrics.

---

## Cross-app integration mechanism

When app A needs to know about app B, write `apps/A/terraform/integrations/B.tf`. The file is gated by a per-integration toggle and a check that both apps are enabled.

```hcl
# apps/n8n/terraform/integrations/nextcloud.tf
# Creates an Authentik service account that n8n uses to talk to Nextcloud's API.

variable "integrate_with_nextcloud" {
  description = "If true, provision a service account with access to Nextcloud's group. Requires apps/nextcloud to be enabled."
  type        = bool
  default     = false
}

variable "nextcloud_application_group_id" {
  description = "Pass module.nextcloud.authentik_application_group_id. Required when integrate_with_nextcloud = true."
  type        = string
  default     = null
}

resource "random_password" "n8n_svc_account" {
  count   = (var.enabled && var.integrate_with_nextcloud) ? 1 : 0
  length  = 32
  special = false
}

resource "authentik_user" "n8n_service" {
  count    = (var.enabled && var.integrate_with_nextcloud) ? 1 : 0
  username = "svc-n8n@${var.base.domains.base_domain}"
  type     = "service_account"
  groups   = [
    authentik_group.this[0].id,                 # n8n's own app group
    var.nextcloud_application_group_id,         # Nextcloud's app group
  ]
  # ...
}
```

In the consumer:

```hcl
module "n8n" {
  source                            = "git::...//apps/n8n/terraform?ref=v2.1.0"
  enabled                           = try(var.apps.n8n.enabled, false)
  hostname                          = try(var.apps.n8n.hostname, "")
  base                              = module.base
  integrate_with_nextcloud          = try(var.apps.n8n.integrate_with_nextcloud, false)
  nextcloud_application_group_id    = module.nextcloud.authentik_application_group_id
}
```

If Nextcloud is disabled, `module.nextcloud.authentik_application_group_id` is `null`, and the integration's `count` evaluates to 0 because `var.integrate_with_nextcloud` must be explicitly set to true. The consumer should also assert via documentation that they only set the toggle when both apps are enabled.

---

## Outpost binding mechanism

The Authentik embedded outpost lives in `platform/identity/terraform/` and binds forward-auth provider IDs from any enabled forward-auth app (Backrest variants, BentoPDF, etc.).

`platform/identity/terraform/` exposes a variable:

```hcl
variable "extra_forward_auth_provider_ids" {
  description = "Provider IDs from apps/* that need to be bound to the embedded outpost. Pass-through from the consumer."
  type        = list(string)
  default     = []
}
```

In the consumer:

```hcl
module "base" {
  source = "git::...//base?ref=v2.1.0"
  # ...
  extra_forward_auth_provider_ids = compact([
    module.backrest_mgmt.authentik_provider_id,
    module.backrest_tools.authentik_provider_id,
    module.backrest_gateway.authentik_provider_id,
    module.bentopdf.authentik_provider_id,
  ])
}
```

`compact()` drops the `null` outputs from disabled apps. The outpost re-binds on every apply but Terraform handles the diff cleanly.

**The cycle problem**: forward-auth apps need `base.authentik.api_url` (so `module.base` must apply before them), and `base.authentik.outpost_id` must reference their provider IDs (so they must apply before `module.base`). Terraform resolves this because the outpost resource is updated in a second graph pass after the forward-auth apps' providers exist. The first ever apply may need `-target` if Terraform's graph analysis can't break the cycle.

---

## Naming and variable conventions

- **Slugs**: lowercase, hyphens only. App directory = slug. `apps/backrest-mgmt/`, not `apps/backrestMgmt/`.
- **Variable names**: `lowercase_snake_case`. Always.
- **Resource names inside an app**: `this` for the primary resource, descriptive snake_case for others. `authentik_application.this`, `scaleway_object_bucket.attachments`.
- **No hardcoded subdomains in modules.** Consumers pass `hostname = "wiki.example.org"` as a full string. Modules NEVER do `"wiki.${var.domain}"`.
- **No hardcoded group names in leaf modules.** Group taxonomy lives in `platform/identity/terraform/`; apps reference `var.base.authentik.groups["admin"]` etc.
- **Sensitive outputs** are marked `sensitive = true`. Secrets are stored in Scaleway Secret Manager, not in Terraform state where avoidable.
- **Descriptions are mandatory.** Every variable and output has a `description = "..."`. The description is the API doc — it should read as docs, not as a code comment.
- **Defaults**: required inputs have NO default. Optional inputs default to a generic value (`"Tools"` for category) or `null` (meaning "module creates one for me").

---

## Versioning

Tags drive everything. Consumers pin module sources to a tag:

```hcl
source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/outline/terraform?ref=v2.1.0"
```

Tag scheme: `v<major>.<minor>.<patch>` at the repo root. **One tag covers the whole monorepo** — every module under `base/`, `apps/`, and `modules/` is versioned together. This trades fine-grained independence for "the whole platform moves as one", which is the right trade-off for a blueprint.

- **Patch** (`v1.0.1`): bug fixes, doc-only changes. Safe to bump without reading notes.
- **Minor** (`v1.1.0`): additive. New inputs with defaults, new outputs, new apps in `apps/`. Safe to bump.
- **Major** (`v2.0.0`): breaking. Variable renames, removed outputs, resource address changes requiring `terraform state mv`. Release notes detail every required migration step.

A consumer bumps via the `scripts/bump-version.sh <version>` helper (shipped with `consumer-template/`). The script greps for `ref=v` and rewrites in place.

---

## Worked example: Outline

Outline is the simplest non-trivial app: OIDC, DNS record, S3 bucket (attachments), Postgres DB, Docker Compose deploy. No cross-app integrations, no monitoring beyond the default.

### Consumer config (terraform.tfvars)

```hcl
apps = {
  outline = {
    enabled  = true
    hostname = "wiki.example.org"
  }
}
```

### Module call (consumer apps.tf)

```hcl
module "outline" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/outline/terraform?ref=v2.1.0"
  enabled  = try(var.apps.outline.enabled, false)
  hostname = try(var.apps.outline.hostname, "")
  base     = module.base
}
```

### What the bundle provisions (when enabled = true)

| Layer       | Resource                                                                |
|-------------|-------------------------------------------------------------------------|
| Authentik   | `authentik_provider_oauth2.this` — OIDC provider for Outline           |
|             | `authentik_application.this` — application visible in the user portal   |
|             | `authentik_group.this` — per-app group `app-outline`                    |
|             | `authentik_policy_binding.access_level` — gates access by `access_level`|
|             | `authentik_policy_binding.application_group` — explicit per-app grant   |
| DNS         | `scaleway_domain_record.this` — A record `wiki.example.org` → host IP  |
| Storage     | `scaleway_object_bucket.attachments` — bucket for user uploads          |
|             | `scaleway_iam_application.outline` — IAM principal for bucket access    |
|             | `scaleway_iam_api_key.outline` — credentials, stored in secret          |
| Database    | `scaleway_rdb_database.outline` — DB in the shared Postgres instance    |
|             | `scaleway_rdb_user.outline` — DB user                                   |
|             | `random_password.outline_db` — DB password                              |
| Secrets     | `scaleway_secret.outline` — bag of secrets for the Ansible role        |
|             |   - OIDC client_id, client_secret                                       |
|             |   - DATABASE_URL                                                        |
|             |   - SECRET_KEY (random)                                                 |
|             |   - AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for the bucket            |

### What the Ansible role does

`platform/apps/outline/ansible/role/tasks/main.yml`:
1. Fetches the bag of secrets from Scaleway Secret Manager (uses base's `scw-secrets` role)
2. Renders `docker-compose.yml.j2` with the secret values and the Outline image
3. Renders `env.j2` with non-secret config (FORCE_HTTPS=true, hostname, etc.)
4. Ensures Traefik labels are present on the compose service for routing
5. Runs `docker compose up -d` on the target host

`platform/apps/outline/ansible/playbook.yml`:
```yaml
- name: Deploy Outline
  hosts: "{{ outline_host_group | default('apps') }}"
  become: true
  roles:
    - role: outline
```

### Consumer site.yml

```yaml
- import_playbook: ../apps/outline/ansible/playbook.yml
- import_playbook: ../apps/steward/ansible/playbook.yml
# ... etc; comment lines for apps you don't want
```

### What this proves

- One tfvars flag and one `import_playbook` line is the entire user-facing footprint to enable an app.
- Disabling Outline (`enabled = false`) leaves no resources, no Authentik config, no Scaleway bucket, no DB. The compose stack on the host needs explicit `docker compose down` from a separate cleanup step (Ansible doesn't auto-undeploy).
- A consumer that only wants Outline plus base carries no state for any other app bundle.
- Adding a new app to the catalog is a contained PR: `apps/<new-app>/` is the entire scope, plus an entry in `consumer-template/`.
