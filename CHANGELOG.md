# Changelog

All notable changes to sabokit go here. Versioning follows semver; major bumps signal breaking contract changes for consumers.

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
