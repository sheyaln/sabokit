# Changelog

All notable changes to sabokit go here. Versioning follows semver; major bumps signal breaking contract changes for consumers.

## v2.9.1 — Scaleway TEM observability reshape: Grafana dashboard + alerts + n8n alert router

Outbound-email observability moves from a standalone n8n polling/alerting workflow to the Grafana stack already in the platform. Cleaner separation: Grafana owns thresholds + visualization, n8n owns notification routing.

### What's new

**Prometheus bundle (`platform/apps/prometheus/`)**
- New opt-in TEM exporter sidecar (`tem_exporter_enabled = true`). Python script in `ansible/roles/prometheus/files/tem-exporter/` running in `python:3.12-alpine` with `pip install` on start — no custom registry image. Polls Scaleway's TEM REST API (`/statistics` + `/emails`) every minute, exposes per-status + per-flag counters on `:9111/metrics`.
- New bundled dashboard `monitoring/dashboards/scaleway-tem.json` (bounce rate, spam complaint rate, failure rate, throughput by status, flag breakdown, exporter health).
- New bundled alert rules `monitoring/alerts/scaleway-tem.yml`: hard-bounce rate >5%, spam-complaint rate >1% (critical), failure rate >10%, sending backlog >50, no-traffic-1h (info), exporter-down. The Ansible role copies these into `/etc/prometheus/rules/` when the exporter is enabled.
- New TF vars: `tem_exporter_enabled`, `tem_smtp_secret_id`, `tem_scaleway_project_id`, `tem_scaleway_region`, `tem_exporter_poll_interval_seconds`, `tem_exporter_lookback_minutes`.
- Credential reuse: the exporter's Scaleway API key is the TEM SMTP password already in `base.scaleway.smtp_config_secret_id` (Scaleway's TEM SMTP password IS an IAM key with `TransactionalEmailFullAccess`). No new secret to manage.

**n8n bundle (`platform/apps/n8n/`)**
- New workflow `grafana-alert-router.json`. Webhook receiver on `/webhook/grafana-alerts` consuming Grafana's standard alert payload (`alerts[]` with `status`/`labels`/`annotations`/`startsAt`/`generatorURL`/`silenceURL`). Routes by `labels.severity` (critical → Slack + email; warning → Slack; info → Slack one-liner). Configure as a Grafana webhook contact point.
- Existing `tem-delivery-alerting.json` is **deprecated but retained** — it still works as a TEM SNS-webhook receiver for per-event alerts if that's wired. The README directs new deployments to the Grafana path.

**Consumer-template (`consumer-template/modules/stack/apps.tf`)**
- `module.prometheus` now wires the new TEM exporter inputs through from `var.apps.prometheus.*` and pulls the smtp-config secret ID + project + region from `local.base.scaleway.*` automatically. Ref bumped `v2.9.0` → `v2.9.1`.

**Manifest (`consumer-template/apps-manifest.yaml`)**
- Prometheus schema gains `tem_exporter_enabled`, `tem_exporter_poll_interval_seconds`, `tem_exporter_lookback_minutes` (all advanced UI).

### Migration

For consumers already on `tem-delivery-alerting.json`:

1. Bump prometheus module to `?ref=v2.9.1`.
2. Set `apps.prometheus.tem_exporter_enabled = true` in tfvars. Apply.
3. Re-run the prometheus playbook (or `site.yml`). Sidecar starts; `/etc/prometheus/rules/scaleway-tem.yml` appears.
4. Import `grafana-alert-router.json` in n8n. Activate it.
5. In Grafana → Alerting → Contact points, create a webhook contact point at `https://<n8n hostname>/webhook/grafana-alerts`. Set it as the default for the `scaleway-tem` rule group's notification policy.
6. The old `tem-delivery-alerting.json` workflow can be left in place (still works if your TEM SNS webhook is wired to its `/webhook/tem-delivery` path) or deactivated/deleted.

### Non-breaking for consumers not using TEM

The exporter is opt-in (`tem_exporter_enabled = false` default). Existing prometheus deployments are unaffected.

---

## v2.9.0 — Tier cascade for Authentik access

Single, declarative, batteries-included access model: a chain of Authentik groups (default `member → delegate → treasurer → admin`) where each tier inherits all lower tiers via Authentik group nesting. App bundles gate on a single tier; users in that tier or any higher one get in.

### New shared module: `modules/authentik/tier-cascade`

Builds the chain of `authentik_group` resources with `parents` wired so the highest-privilege tier sits at the bottom of the chain and cascades upward. Outputs:

- `groups` — flat `name → id` map (merged into `base.authentik.groups`, backwards-compatible with existing app bundles).
- `tier_cascade` — `map(tier → map(tier → group_id))` where `tier_cascade[T]` lists every tier at-or-above `T`. Bundle's `authorized_groups` is now a one-line indexed lookup.
- `admin_tier` — echo of the resolved admin tier.

Customise via the existing identity-tier vars (`admin_group_name`, `member_group_name`, `delegate_group_name`, plus the new `treasurer_group_name`) or rewrite the whole list with `tier_names_override`.

`platform/identity/` now instantiates the cascade in place of the inline `authentik_group` resources it used to create. The delegate RBAC role still lives in `roles.tf`; it's attached to the cascade's delegate-tier group via the cascade's `tier_roles` input.

### Per-bundle integration (opt-out)

Every authentik-gated bundle (`outline`, `steward`, `vikunja`, `bentopdf`, `notifuse`, `nextcloud`, `decidim`, `jitsi`, `espocrm`, `n8n`, `grafana`, `wazuh`, `backrest`) gains two variables:

- `tier_cascade_enabled` (default `true`) — derive `authorized_groups` from the cascade.
- `tier_access_level` (default `"member"` for user-facing apps, `"admin"` for ops surfaces) — which cascade tier gates the app.

When `tier_cascade_enabled = false`, the bundle falls back to the existing `access_level` + `extra_authorized_groups` primitive shape — unchanged from v2.8.x. Use this for apps with genuinely unusual gating (a single service-account group, no inheritance, etc.).

Apps without an OIDC surface (`watchtower`, `autoheal`, `wazuh-agent`, `prometheus`, `loki`) and public apps (`privacy-policy`) are untouched.

### Breaking changes

None for consumers on the default cascade. Two edges to watch:

- Consumers who previously created their own group named `treasurer` outside the identity module will collide with the new default tier. Either drop the external group, override `treasurer_group_name = null`, or rename via `tier_names_override`.
- The platform `member`/`admin`/`delegate` groups are now created by the cascade module instead of inline in `user_groups.tf`. Terraform sees these as a resource move; `terraform state mv` from `authentik_group.admin` → `module.tier_cascade.authentik_group.tier["admin"]` (and similarly for `member`/`delegate`) avoids destroy/recreate. Without the move terraform will recreate them, which loses any UI-managed group attributes (but not user membership, since that's stored on the user side in Authentik).

### Other

- Consumer-template refs bumped `v2.8.1` → `v2.9.0`.
- Manifest gains `tier_cascade_enabled` and `tier_access_level` entries for all 13 cascade-integrated bundles.

---

## v2.8.1 — Fix: static graph cycle in platform/identity outpost output

**Bug (existed since v2.4.0, reported v2.8.0 by dciww-consumer):** any consumer following the documented forward-auth wiring pattern hit a `terraform plan` cycle error:

```
module.identity.var.extra_forward_auth_provider_ids →
  resource.authentik_outpost.embedded →
  output.authentik (referenced authentik_outpost.embedded[0].id) →
  local.base.authentik →
  module.<forward-auth-app>.var.base →
  module.<forward-auth-app>.authentik_provider_id →
  module.identity.var.extra_forward_auth_provider_ids
```

The `length() > 0 ? resource : data` ternary on `outpost_id` looks runtime-conditional but terraform's graph analyzer sees both edges unconditionally.

**Fix:** source `outpost_id` from `data.authentik_outpost.embedded.id` unconditionally. The data source and the managed resource point at the same singleton Authentik outpost (built-in "authentik Embedded Outpost"), so their UUIDs are equal — sourcing from the data source breaks the output→resource edge without losing functionality. The managed resource still exists, still attaches providers, terraform still applies it.

Workaround (for consumers staying on v2.8.0 and earlier): set `extra_forward_auth_provider_ids = []` in your identity module call, accept that forward-auth-protected apps (bentopdf, backrest) are unprotected until you bump to v2.8.1.

### Other

- Consumer-template refs bumped `v2.8.0` → `v2.8.1`.

---

## v2.8.0 — Scaleway TEM in base + new `platform/bootstrap/` tier (IMAP via protonmail-bridge)

Two architectural additions.

### Scaleway TEM in `platform/base/`

Outbound SMTP for every app now ships with base. Adds `scaleway_tem_domain` + SPF/DKIM/DMARC DNS records + a dedicated TEM IAM application + the well-known `smtp-config` Scaleway secret. App bundles already reference `smtp_secret_name = "smtp-config"` by convention; once base is applied, apps get working outbound mail with no per-app config.

New base TF vars:
- `tem_enabled` (default `true` — flip to `false` only if managing SMTP out-of-band)
- `tem_sender_domain` (default = `base_domain`)
- `tem_from_email` (default `notify@<sender_domain>`)
- `tem_smtp_config_secret_name` (default `smtp-config`)

New base outputs: `scaleway.smtp_config_secret_id`, `scaleway.smtp_from_email`.

### New `platform/bootstrap/` tier + protonmail-bridge bundle

Sibling to `platform/base/`, `platform/identity/`, `platform/apps/`. Houses runtime-dependency services beyond what base provides. SMTP isn't bootstrap (it's in base — every app needs it + it's a managed Scaleway service); the tier exists for narrower shared dependencies.

First bootstrap bundle: **`platform/bootstrap/protonmail-bridge/`** — IMAP gateway. Apps that need to FETCH mail (typically n8n workflows polling an inbox) consume the `imap-config` Scaleway secret this bundle writes.

ARCHITECTURE.md gains a new "Tiers" section defining all four tiers, the 5-criteria bootstrap-vs-apps test, and why SMTP-via-TEM lives in base while protonmail-bridge lives in bootstrap.

### Breaking changes

`tem_enabled = true` by default. Consumers upgrading from v2.7.x who already manage `smtp-config` externally need to either:
- Set `apps.<your-app>.smtp_secret_name` to a non-default name, OR
- Set `tem_enabled = false` on the base module + keep their existing secret in place.

The TEM DNS records (SPF/DKIM/DMARC) are appended to the consumer's `base_domain` zone. If the zone is managed outside Scaleway DNS, set `tem_enabled = false` and provision the records manually.

---

## v2.7.2 — Wazuh dashboard native OIDC

Replaced the v2.7.0 forward-auth gateway pattern with native OIDC on the Wazuh dashboard via opensearch-security's `openid` authc backend.

### Changes
- `platform/apps/wazuh/terraform/authentik.tf`: switched from `authentik/traefik-forward-auth` to `authentik/oidc-app`. New OIDC scopes + redirect URI on `/auth/openid/login`.
- `secrets.tf`: app-secrets bag now also carries `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` / `OIDC_DISCOVERY_URL` / `OIDC_BASE_REDIRECT_URL`.
- `config.yml.j2`: opensearch-security's `authc` block now lists `oidc_auth_domain` (type `openid`) first, with the basic internal auth domain kept as fallback (the dashboard service account `kibanaserver` still uses HTTP basic).
- `opensearch_dashboards.yml.j2`: `opensearch_security.auth.type: ["basicauth", "openid"]` + the OIDC config block (connect_url, client_id, client_secret, scope, base_redirect_url, logout_url) wired from env.
- `roles_mapping.yml.j2`: maps the Authentik admin group (`oidc_admin_group` var, default `admin`) to `all_access`; all OIDC-authenticated users get baseline `kibana_user`.
- New TF var: `oidc_admin_group` (default `admin`).
- Consumer-template: removed `module.wazuh.authentik_provider_id` from `extra_forward_auth_provider_ids` in `identity.tf` (no longer forward-auth gated); added `oidc_admin_group` passthrough in the wazuh module block.

### Breaking change

Existing v2.7.0/v2.7.1 deployments transitioning to v2.7.2 will:
- Lose the forward-auth gateway layer on the dashboard (Authentik no longer pre-gates; the dashboard handles auth directly).
- Need to remove the wazuh `extra_forward_auth_provider_ids` entry in identity.tf (the v2.7.2 consumer-template already does this).
- Get a fresh Authentik OIDC provider (the `oidc-app` module is a different resource type than `traefik-forward-auth`, so terraform will destroy/recreate the provider). User sessions are not affected — they were never persisted in Authentik forward-auth anyway.

---

## v2.7.1 — Wazuh agent bundle

Companion to the v2.7.0 server stack. Multi-instance — deploy once per monitored host.

### New bundle

- **`platform/apps/wazuh-agent/`** — `wazuh/wazuh-agent` container on the host network. Auto-enrolls via `WAZUH_MANAGER_SERVER` env var. `release_version` MUST match the manager's. Consumer-template example block uses key `wazuh_agent_apps`; copy per host to monitor more.

### No breaking changes

Additive. Ref bumps `v2.7.0` → `v2.7.1` across consumer-template, manifest extended (19 apps), `scripts/gen_apps_yml.py` extended, `platform/ansible/apps.yml` regenerated.

---

## v2.7.0 — Wazuh server stack

New `platform/apps/wazuh/` bundle: three lockstep containers (manager + indexer (OpenSearch fork) + dashboard) with SSL certs auto-generated via the official `wazuh-certs-generator` one-shot. UI gated by Authentik forward-auth at the gateway; native OIDC for the dashboard would require custom `config.yml` for the opensearch-security plugin (deferred).

### New bundle

- **`platform/apps/wazuh/`** — manager (TCP 1514/1515 + UDP 514 for agents, 55000 API on 127.0.0.1) + indexer + dashboard. Sets `vm.max_map_count` via sysctl (OpenSearch requirement). Internal-user passwords pinned (`ignore_changes = all`).
- `required_inbound_rules` emits the agent ports; consumer-template aggregates into base's SG.
- Agent role for monitored hosts: deferred to v2.7.1.

### Variable note

Wazuh's release version is exposed as **`release_version`** (not `version`) because `version` is reserved in TF module blocks.

### Consumer-template + manifest + autogen

- Module ref bumped `v2.6.0` → `v2.7.0`.
- Forward-auth provider_id added to `extra_forward_auth_provider_ids` in `identity.tf`.
- `required_inbound_rules` aggregation in `base.tf` extended.
- `enabled_apps` output extended; `apps-manifest.yaml` now lists 18 apps; `scripts/gen_apps_yml.py` BUNDLES list extended; `platform/ansible/apps.yml` regenerated.
- `tests/local-validate`: `terraform validate` green across 18 bundles.

### No breaking changes

Additive. Opt in with `apps.wazuh.enabled = true`.

---

## v2.6.0 — Monitoring stack (prometheus + loki + grafana)

Three new bundles forming the standard observability triad. Headless prometheus + loki with grafana fronting via Authentik OIDC. Shared `monitoring_internal` docker network (each bundle creates it idempotently).

### New platform bundles

- **`platform/apps/prometheus/`** — TSDB + optional `node_exporter` + `cadvisor` sidecars. Headless (binds 127.0.0.1 by default; set `private_ip_bind` to expose on the VPC). Scrape configs and alert rules are aggregated by consumer-template from each enabled app's `monitoring.prometheus_scrape_configs` / `monitoring.alert_rules` — bundles own their scraping, consumer plumbs.
- **`platform/apps/loki/`** — single-tenant filesystem-backed log aggregator. Receives Alloy/Promtail pushes on port 3100 (default 127.0.0.1). For multi-tenant or S3-backed deployments, replace `templates/loki-config.yml.j2`.
- **`platform/apps/grafana/`** — UI behind Authentik OIDC. Prometheus + Loki datasources auto-provisioned via the shared network. OIDC role mapping: configurable `oidc_admin_group` / `oidc_editor_group` → Admin/Editor; everyone else → Viewer. Dashboards via file-provider in `/opt/grafana/provisioning/dashboards/`.

### Consumer-template wiring

- `local.aggregated_scrape_configs` + `local.aggregated_alert_rules` collect from every enabled app's `monitoring` output and pass into the prometheus module. Backup-plan aggregation extended to cover the 3 new bundles.
- `module "prometheus"`, `module "loki"`, `module "grafana"` blocks added with sensible defaults.
- `enabled_apps` output extended with the 3 new entries.
- All module refs bumped `v2.5.0` → `v2.6.0`.

### Manifest + autogen

- 3 new manifest entries (17 apps total). `bash scripts/check-manifest-coverage.sh` clean (0 errors).
- `scripts/gen_apps_yml.py` BUNDLES list extended; `platform/ansible/apps.yml` regenerated.
- `tests/local-validate`: `terraform validate` green across base + identity + 17 app bundles.

### No breaking changes

This is additive; existing v2.5.0 consumers can opt in with `apps.prometheus.enabled = true` etc.

---

## v2.5.0 — Retro feature survival + plug-and-play ops payload

Two themes:
1. **Retroactive feature audit** — port everything the dciww-commons fork ran in prod but that didn't survive the initial upstream port.
2. **Prod-default ops payload** — Watchtower + Autoheal + Backrest are now plug-and-play; every app contributes its labels + backup plan, the consumer just wires the platform bundles once per host.

### New platform bundles

- `platform/apps/watchtower/` — one container per host, auto-updates opted-in containers via the standard `com.centurylinklabs.watchtower.enable=true` label. Default schedule 04:00 UTC daily (offset from Backrest 02:00). Optional Slack post-update notifications.
- `platform/apps/autoheal/` — one container per host, restarts containers whose healthcheck flips to unhealthy. Opt in via `autoheal=true` label.

### Per-app knobs (every bundle, including authentik)

Each app now exposes:
- `auto_update_enabled` — render the Watchtower label. Smart defaults: ON for stateless / safe-update apps (bentopdf, outline, vikunja, steward, notifuse, privacy-policy, backrest), OFF for breaking-change apps (nextcloud, decidim, espocrm, n8n, jitsi, authentik).
- `autoheal_enabled` — render the Autoheal label. Default ON everywhere (restart-on-unhealthy is low-risk).
- `backup_enabled` — emit a Backrest plan contribution. Default ON for apps with host-side state; OFF for stateless (bentopdf, privacy-policy, jitsi).
- `backup_extra_paths`, `backup_schedule_cron`, `backup_retention` — per-app overrides on the auto-generated plan.

### New bundle output

- `backup_plan` (every bundle) — Backrest plan contribution, null when disabled. Same plug-and-play shape as `required_inbound_rules`. Consumer-template now aggregates and passes the full list to every Backrest instance; restic skips paths that don't exist on its host.

### Feature restorations from the fork

- **nextcloud** — full configure-script restoration: instance name knob (default "Nextcloud", was hardcoded "Sabo Cloud"); maintenance window knob; auto-install of 8 default apps (groupfolders, notify_push, notes, tasks, forms, polls, epubviewer, webhook_listeners); n8n form-webhook registration via OCS API; file-handling defaults (preview limit, JPEG quality, distributed file locking, versions retention, activity expiry, log rotate); `maintenance:repair --include-expensive` pass at end.
- **decidim** — restored memcached fragment-cache container (silent perf downgrade without it). New `extra_gems` mechanism: bundle renders a Dockerfile that extends the upstream image, appends gem lines, re-runs `bundle install` + `assets:precompile`. Default ships `decidim-elections`.
- **outline** — `oidc_username_claim` knob (default `preferred_username`, was hardcoded).
- **vikunja** — `default_week_start` knob.
- **bentopdf** — fixed default image to `ghcr.io/alam00000/bentopdf` (the official one; previous default pointed at a different project).
- **notifuse** — exposed `image` override + `build_from_source` mechanism (clones github.com/sheyaln/notifuse `feat/oidc-v1` and builds on host). Default `build_from_source = true` so OIDC ships out of the box; stock notifuse has no OIDC.

### n8n

- **Dropped** `build_from_source` toggle — external runners are the right design. The runners image already carries python; layering python on n8n itself was solving the wrong problem.
- **Ported 8 generic workflows from the fork** (scrubbed of org markers, deactivated by default): `error-notification`, `infra-notifications-receiver`, `scaleway-billing-forecast`, `tem-delivery-alerting`, `authentik-user-lifecycle-notifier`, `espocrm-membership-notifier`, `nextcloud-form-submission-notifier`, `nextcloud-form-edit-access-notifier`.
- **Ported the Jotform notifier** as a genericized `jotform-submission-notifier` (form ID + channel are placeholders; the Code node walks the full submission payload so no per-form field mapping is needed).
- README workflow library + credential table expanded.

### Documentation

- `ARCHITECTURE.md` — new "Plug-and-play platform contributions" subsection codifying the bundle-output → consumer-aggregation pattern across SG rules, backup plans, and monitoring.

### Consumer-template changes

- Bumped every module ref `v2.3.0 → v2.5.0`.
- Added `watchtower_apps` and `autoheal_apps` module blocks (multi-instance, mirrors `backrest_mgmt`).
- `backrest_mgmt.backup_plans` is now `concat(local.aggregated_backup_plans, var.apps.backrest_mgmt.backup_plans)` — bundles contribute, consumer extras still possible.
- `apps-manifest.yaml` has 14 entries now (12 user-facing + watchtower + autoheal).

### Breaking changes

- `n8n.build_from_source` — variable removed. If your consumer config passes it, drop the line.
- `notifuse.build_from_source` default changed from `false` to `true`. If you were relying on stock notifuse (no OIDC), set `build_from_source = false` explicitly.
- `bentopdf.image` default changed from `ghcr.io/digital-blueprint/bento-pdf:latest` to `ghcr.io/alam00000/bentopdf:latest`. If you were intentionally pinning to the digital-blueprint image (different project), set `image` explicitly.

---

## Prior releases

See `git log --oneline v2.4.0` and earlier. No changelog was kept before v2.5.0.
