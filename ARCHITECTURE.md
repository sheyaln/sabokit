# Sabokit Architecture

This document is the **contract** for module authors and consumers. It defines how `platform/`'s four layers, the shared `_shared/` wrappers, and `consumer-template/` fit together and what each must guarantee.

If you are adding a new app bundle, building a new base sub-module, or writing a new consumer, this is your spec.

## Table of contents

- [Layered model](#layered-model)
- [Terraform vs Ansible](#terraform-vs-ansible)
- [The base ↔ app contract](#the-base--app-contract)
  - [What `base` provides](#what-base-provides)
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

## Layers

The repo organizes bundles by **what they're a dependency of**, not by what they do. Four layers, each its own Terraform state, ordered by who-depends-on-whom:

| Layer | Path | What lives here | Apply order |
|-------|------|-----------------|-------------|
| **Infra** | `platform/infra/` | Scaleway substrate — VPC, RDB (incl. Authentik's DB), IAM, Secret Manager, DNS zones, per-role security groups, the shared Postgres instance, **Scaleway TEM** for outbound SMTP (writes the well-known `smtp-config` secret every app sends through), and the Authentik **bootstrap** secrets (admin/DB/token — the root of trust). Sub-tier `platform/infra/host-services/` holds per-host watchers (diun, autoheal, wazuh-agent) that auto-instantiate from every compute host. | First — birth-once. |
| **Identity** | `platform/identity/` | The SSO server config (Authentik): flows, brand, tier groups + their nesting. Configured via the Authentik API. Every OIDC/forward-auth app pulls its provider info from here. | After infra. |
| **Operations** | `platform/operations/` | Monitoring + SIEM every consumer gets by default — Loki (logs), Prometheus (metrics + rules), Grafana (dashboards + alerting), Wazuh manager (SIEM) — plus the `protonmail-bridge` IMAP gateway for mail-fetching apps. Each service flippable via its `<svc>.enabled` flag (default `true`). | After identity. |
| **Application** | `platform/application/` | User-facing apps + the embedded forward-auth outpost + `backrest` (per-host backups). Apps consume the layers below and never each other (except gated `integrations/`). | Last — churns most. |

The layers **self-discover** each other by name: a downstream layer rebuilds its `base` object from tagged `${org}-${env}-…` Scaleway + Authentik data sources (`platform/_shared/contract/`), not from `remote_state`. The dependency DAG is `infra → identity → {operations, application}`.

### Where SMTP and IMAP live

SMTP is a managed Scaleway product (TEM) with no host-side runtime, so it lives in **infra** (which already owns Scaleway resources) and writes `smtp-config`. The one runtime mail provider, `protonmail-bridge` (IMAP, for apps that *fetch* mail), is an **operations** bundle writing `imap-config`. Apps consume both by well-known secret name, never via app-to-app TF references.

### Host-services sub-tier (under infra)

`platform/infra/host-services/` holds per-host runtime watchers — one instance per `compute_hosts` entry, fanned out by `platform/infra/terraform/host_services.tf`. Consumer surface is the `<service>.{enabled, disabled_hosts, ...}` block in `infra.yml`; no per-host `module ".." { ... }` blocks in the consumer. They sit under infra because every host needs them by default and bind to the host's lifecycle, not an app's. The fleet: `diun/` (notify-on-new-image), `autoheal/` (restart unhealthy containers), `wazuh-agent/` (log shipper to the wazuh manager).

---

## Layered model

```
platform/_shared/        # Low-level Terraform primitives + Authentik app wrappers +
                         # the data-source contract. No environment specifics.
                         #   infrastructure/{network, compute, postgres, object_bucket,
                         #   secrets, app_dns, …}, authentik/{oidc-app, saml-app, …},
                         #   contract/ (rebuilds `base` from ${org}-${env} data sources).

platform/infra/          # Layer 1. Scaleway substrate + Authentik bootstrap secrets +
                         # host-services. Birth-once.

platform/identity/       # Layer 2. Authentik flows + tier groups + brand (via the API).

platform/operations/<svc>/   # Layer 3. loki, prometheus, grafana, wazuh, protonmail-bridge.

platform/application/<name>/ # Layer 4. One self-contained bundle per app. Owns its
                         # Authentik OIDC/SAML resources, DNS records, S3 bucket,
                         # database, secrets, monitoring artifacts, and Ansible deploy
                         # role. Inert when disabled.

consumer-template/       # The starter a new org copies. One Terraform root per layer
                         # under environments/<env>/; the per-layer scripts deploy them.
```

**Dependency direction**: each consumer root → its `platform/<layer>/terraform` → `platform/_shared/*`. Downstream layers discover upstream resources by tag (no cross-layer TF references); `_shared/*` depends on nothing in this tree.

Apps never depend on each other directly. Cross-app coupling lives in `platform/application/<name>/integrations/<other-app>.tf` and is gated by a toggle that only fires if both apps are enabled.

---

## Terraform vs Ansible

**The rule:** Terraform owns cloud + API state. Ansible owns convergent host-side execution. Every bundle has both halves; neither half reaches across the line.

### What lives on each side

**Terraform** owns anything with an identity in an external system you reconcile against:

- Scaleway primitives — instances, RDB databases, VPC, security groups, DNS records, Secret Manager secrets, IAM apps + API keys, object buckets, TEM domains.
- Authentik objects — providers, applications, groups, flows, sources, outposts, brand.
- Generated values that must exist before Ansible runs — random passwords stashed in Scaleway secrets, OIDC client IDs/secrets, hostnames, image tags.
- Anything `terraform destroy` should clean up.

**Ansible** owns anything that mutates state inside a host TF already provisioned:

- Rendering `docker-compose.yml.j2` and `env.j2` with the hostnames, image tags, and secret IDs TF produced.
- Pulling secret payloads at deploy time via `lookup('scaleway.scaleway.scaleway_secret', <id>)`.
- Running `docker_compose_v2` to converge containers, creating docker networks, dropping config files (`ossec.conf`, Grafana provisioning, Prometheus rules), running idempotent host tasks.

### The bridge: `output "ansible"`

Every bundle's TF emits one map describing how Ansible should deploy it. Example from `platform/application/outline/terraform/outputs.tf`:

```hcl
output "ansible" {
  value = var.enabled ? {
    role_path  = "${path.module}/../ansible/role"
    playbook   = "${path.module}/../ansible/playbook.yml"
    host_group = var.base.compute.hosts[var.deployment_host_key].ansible_group
    vars = {
      outline_hostname                 = var.hostname
      outline_image_tag                = var.image_tag
      outline_app_secret_id            = scaleway_secret.app[0].id
      outline_db_credentials_secret_id = module.database[0].secret_id
      # ...
    }
  } : null
}
```

The consumer rolls these up into `enabled_apps`, dumps it, and feeds it to Ansible:

```bash
terraform output -json enabled_apps > .enabled_apps.json
ansible-playbook platform/ansible/site.yml -i inventory.ini -e @.enabled_apps.json
```

That map is the entire contract. TF says "here's the role, here's the host group, here are the vars." Ansible runs it. Neither side knows more about the other than what's in the map.

### Deciding where a new thing belongs

When you don't know which side something goes on, ask in this order:

1. Does it need an identity in an external system to reconcile against (Scaleway, Authentik, DNS)? → **TF.**
2. Does it mutate state inside an already-provisioned host (compose files, container state, on-disk config)? → **Ansible.**
3. Does it need to exist *before* the other side runs? → **TF.** Ansible reads TF output; the reverse never holds.

### The asymmetry, and what breaks when you cross it

TF runs once per environment against a global state file. Ansible runs idempotently per-host against the host's filesystem. They are not interchangeable.

- **Managing docker-compose files in TF** (e.g. with `local_file` or `null_resource` + `remote-exec`): every consumer apply now requires SSH access from wherever TF runs, the host has to be reachable at plan time, and a single host being down breaks the plan for every other host. Compose belongs in Ansible.
- **Managing Scaleway resources in Ansible** (e.g. via `scaleway.scaleway` modules in a role): no central state, no `terraform destroy`, no plan diff, no drift detection. Recreating a deleted bucket means writing imperative discovery logic that TF gives you for free. Scaleway belongs in TF.

### Edge case: Scaleway Secret Manager

Secrets have a deliberate split. TF *writes* the secret — creates the `scaleway_secret` resource and a `scaleway_secret_version` with the initial payload. Ansible *reads* it at deploy time via the `scaleway.scaleway.scaleway_secret` lookup. The payload never appears in TF state diffs after creation, and Ansible never holds the secret long enough to log it. Pattern in any bundle (Outline shown):

```hcl
# terraform/secrets.tf
resource "scaleway_secret_version" "app" {
  secret_id = scaleway_secret.app[0].id
  data      = jsonencode({ SECRET_KEY = random_id.secret_key[0].hex, ... })
}
```

```yaml
# ansible/roles/outline/tasks/main.yml
outline_app_secrets: "{{ lookup('scaleway.scaleway.scaleway_secret', _outline_app_secret_uuid) | b64decode | from_json }}"
```

TF passes the *secret ID* to Ansible (in the `ansible` output map). Ansible resolves the ID to the payload at deploy time.

### How credentials get seeded

Every credential-generating bundle uses `random_password` / `random_id` to generate its secrets on first apply, writes them into a Scaleway secret bag, and pins the bag content via `lifecycle { ignore_changes = [data] }` on the `scaleway_secret_version` so subsequent applies never rotate the values. To rotate, taint the relevant resource.

For consumers migrating off a pre-v3 stack: bring credentials over by populating the bag out-of-band (`scw secret-manager` or console), then `terraform import` the `scaleway_secret.app` / `scaleway_secret_version.app` resources before first apply. The `ignore_changes = [data]` keeps the imported payload while terraform takes ownership of the surrounding resources.

---

## The base ↔ app contract

### What `base` provides

`base` is the contract surface for every app — assembled by `platform/_shared/contract/` from the infra + identity layers' tagged resources, and passed to each bundle as `var.base`. Every field here is stable across patch and minor releases. Breaking these is a major version bump.

The contract is split by concern:

```hcl
# From platform/infra/terraform/outputs.tf
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
      ansible_group = string  # e.g. "tools", "identity", "management"
      role         = string  # what this host is intended for: "tools", "identity", "management"
    }))
  }
}

# From platform/identity/terraform/outputs.tf
output "authentik" {
  description = "Authentik platform handles. Apps use these to register OIDC/SAML/proxy providers."
  value = {
    api_url              = string  # for the provider block
    api_token_secret_id  = string  # Scaleway Secret Manager ID
    identity_domain       = string  # e.g. "auth.example.org"
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

Every app bundle MUST declare these inputs in `platform/application/<name>/variables.tf`:

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

variable "authorized_groups" {
  description = "Authentik group NAMES allowed to access this app; each must exist in base.authentik.groups. The bundle binds one access policy per group, and Authentik nests higher tiers under lower, so naming a baseline tier admits every tier above it."
  type        = list(string)
  default     = ["admin"]
  # No validation enum — base provides the group taxonomy, apps reference it.
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, this app's metrics/dashboards/logs are wired up."
  type        = bool
  default     = true
}
```

An app MAY declare additional inputs for its own specifics (e.g. `outline_smtp_from_address`). Always namespaced by the app slug.

### What every app bundle exports

Every app bundle MUST export these outputs in `platform/application/<name>/outputs.tf`:

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

output "required_inbound_rules" {
  description = "Security group rules required for this app to function. Aggregated by the consumer into base's default_security_group_extra_inbound_rules."
  value = (var.enabled && <condition>) ? [
    { protocol = "TCP|UDP", port = number, port_range = "lo-hi", ip_range = "cidr" },
  ] : []
}

output "backup_plan" {
  description = "Backrest backup plan contribution. Aggregated by the consumer into backrest's backup_plans."
  value = (var.enabled && var.backup_enabled) ? {
    id        = local.slug
    paths     = list(string)   # /backup-sources/opt/<slug> + var.backup_extra_paths
    excludes  = list(string)
    schedule  = { cron = string }
    retention = { hourly = number, daily = number, weekly = number, monthly = number, yearly = number }
  } : null
}

output "split_dns_entries" {
  description = "Public-hostname -> private-IP overrides for cross-host resolution. Aggregated by the consumer-template."
  value = var.enabled ? [
    { hostname = var.hostname, private_ip = var.base.compute.hosts[var.deployment_host_key].private_ip },
  ] : []
}
```

The `null when disabled` pattern is load-bearing. Consumers and other apps use `coalesce(module.outline.monitoring, {})` patterns to drop disabled apps from aggregation.

### Plug-and-play platform contributions

Four outputs follow the **bundles own their requirements, consumers just plumb** pattern:

| Output | Aggregated into | Pattern |
|--------|-----------------|---------|
| `required_inbound_rules` | `base.default_security_group_extra_inbound_rules` | Each enabled app declares the SG ports it needs open; consumer concats. |
| `backup_plan` | `backrest_<instance>.backup_plans` | Each enabled app declares a default backup plan; consumer collects all non-null and concats with consumer-supplied extras. Each backrest instance gets the full union; restic skips paths that don't exist on its host. |
| `monitoring` | monitoring app's scrape/dashboard/log/alert lists | Each enabled app contributes its observability footprint; monitoring apps merge. |
| `split_dns_entries` | `split_dns_overrides` ansible var (consumed by the base `split-dns` role on every host) | Each app declares the public hostname(s) it owns + the private IP of its deployment host; consumer rolls into one map; dnsmasq on every host overrides those names so cross-host references stay on the private network. Auto-disabled for single-host topologies. |

When you add a new bundle that needs SG ports, host-side filesystem backups, monitoring wiring, or a publicly-resolved hostname: ship the output. When you add a new contributor pattern, document it here and apply it the same way.

The split-dns aggregation makes the monitoring stack truly host-independent: Grafana on the `management` host can reach `loki.example.org` (deployed on `tools`) by its public hostname without going through Let's Encrypt + the public ingress. Without it, multi-host topologies force co-locating Prometheus, Loki, and Grafana on the same host (or rolling consumer-side DNS).

---

## App bundle layout

Every `platform/application/<name>/` directory follows this exact structure:

```
platform/application/outline/
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

Files in `terraform/` may be omitted when not applicable (a static app may have no `database.tf`). Files in `monitoring/` may be empty stubs when the app exposes no metrics. The `ansible/` directory is required for every app (no terraform-only apps in this design — if you only need Authentik config, write a `bookmark` app or extend the infra layer).

---

## The enable/disable mechanism

A consumer's `config.tf` (committable; secrets stay in Scaleway Secret Manager) declares which apps are on by passing the `apps` argument to `module.stack`:

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
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/application/outline/terraform?ref=v2.1.0"
  enabled  = try(var.outline.enabled, false)
  hostname = try(var.outline.hostname, "")
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
# platform/application/outline/terraform/monitoring.tf
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
  enabled        = try(var.prometheus.enabled, false)
  hostname       = try(var.prometheus.hostname, "")
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
# platform/application/n8n/terraform/integrations/nextcloud.tf
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
  enabled                           = try(var.n8n.enabled, false)
  hostname                          = try(var.n8n.hostname, "")
  base                              = module.base
  integrate_with_nextcloud          = try(var.n8n.integrate_with_nextcloud, false)
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
  source = "git::...//base?ref=v3.4.0"
  # ...
  extra_forward_auth_provider_ids = compact(concat(
    [for inst in module.backrest : inst.authentik_provider_id],
    [
      module.bentopdf.authentik_provider_id,
    ],
  ))
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
source = "git::https://github.com/sheyaln/sabokit.git//platform/application/outline/terraform?ref=v2.1.0"
```

Tag scheme: `v<major>.<minor>.<patch>` at the repo root. **One tag covers the whole monorepo** — every layer and bundle under `platform/` is versioned together. This trades fine-grained independence for "the whole platform moves as one", which is the right trade-off for a blueprint.

- **Patch** (`v1.0.1`): bug fixes, doc-only changes. Safe to bump without reading notes.
- **Minor** (`v1.1.0`): additive. New inputs with defaults, new outputs, new apps in `platform/application/`. Safe to bump.
- **Major** (`v2.0.0`): breaking. Variable renames, removed outputs, resource address changes requiring `terraform state mv`. Release notes detail every required migration step.

A consumer bumps via the `scripts/bump-version.sh <version>` helper (shipped with `consumer-template/`). The script greps for `ref=v` and rewrites in place.

---

## Worked example: Outline

Outline is the simplest non-trivial app: OIDC, DNS record, S3 bucket (attachments), Postgres DB, Docker Compose deploy. No cross-app integrations, no monitoring beyond the default.

### Consumer config (config.tf)

`config.tf` is the committable operator-facing TF file. Secrets never go here — they live in Scaleway Secret Manager and surface via `data "scaleway_secret_version"` blocks. The `.tfvars` file format is reserved for the rare case where a consumer needs to pass a plaintext secret value at apply time (gitignored).

```hcl
locals {
  apps = {
    outline = {
      enabled  = true
      hostname = "wiki.example.org"
    }
  }
}
```

### Module call (consumer apps.tf)

```hcl
module "outline" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/application/outline/terraform?ref=v2.1.0"
  enabled  = try(var.outline.enabled, false)
  hostname = try(var.outline.hostname, "")
  base     = module.base
}
```

### What the bundle provisions (when enabled = true)

| Layer       | Resource                                                                |
|-------------|-------------------------------------------------------------------------|
| Authentik   | `authentik_provider_oauth2.this` — OIDC provider for Outline           |
|             | `authentik_application.this` — application visible in the user portal   |
|             | `authentik_group.this` — per-app group `app-outline`                    |
|             | `authentik_policy_binding.authorized` — one binding per `authorized_groups` entry |
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

`platform/application/outline/ansible/role/tasks/main.yml`:
1. Fetches the bag of secrets from Scaleway Secret Manager (uses base's `scw-secrets` role)
2. Renders `docker-compose.yml.j2` with the secret values and the Outline image
3. Renders `env.j2` with non-secret config (FORCE_HTTPS=true, hostname, etc.)
4. Ensures Traefik labels are present on the compose service for routing
5. Runs `docker compose up -d` on the target host

`platform/application/outline/ansible/playbook.yml`:
```yaml
- name: Deploy Outline
  hosts: "{{ outline_host_group | default('tools') }}"
  become: true
  roles:
    - role: outline
```

### Consumer site.yml

```yaml
- import_playbook: ../application/outline/ansible/playbook.yml
- import_playbook: ../application/steward/ansible/playbook.yml
# ... etc; comment lines for apps you don't want
```

### What this proves

- One `config.tf` flag and one `import_playbook` line is the entire user-facing footprint to enable an app.
- Disabling Outline (`enabled = false`) leaves no resources, no Authentik config, no Scaleway bucket, no DB. The compose stack on the host needs explicit `docker compose down` from a separate cleanup step (Ansible doesn't auto-undeploy).
- A consumer that only wants Outline plus base carries no state for any other app bundle.
- Adding a new app to the catalog is a contained PR: `apps/<new-app>/` is the entire scope, plus an entry in `consumer-template/`.
