# Changelog

All notable changes to sabokit go here. Versioning follows semver; major bumps signal breaking contract changes for consumers.

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
