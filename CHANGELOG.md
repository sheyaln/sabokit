# Changelog

All notable changes to sabokit go here. Versioning follows semver; major bumps signal breaking contract changes for consumers.

## v2.13.0 — New bundle: Diun (notify-on-new-image) + watchtower deprecation

**New app bundle**: `platform/apps/diun/` — [crazy-max/diun](https://github.com/crazy-max/diun), pinned `4.31.0`. One container per host; watches the local Docker daemon, polls each container's image registry on a schedule, fires a notification when a tag's digest changes. Multi-instance — example consumer-template block is `diun_mgmt` on the management host. Bundle count: 19 → 20.

**Behaviour shift vs Watchtower**: Diun notifies, it does NOT pull or restart. That's the point — control + visibility over surprise restarts. Operator (or automation) decides whether and when to act on each notification. The two bundles ship side-by-side on purpose, not as a replacement.

**Notifier surface**: `notification_targets = list(any)`, each entry `{ type = "<notifier>", config = { ... } }`. Type ∈ amqp, discord, gotify, mail, matrix, mqtt, ntfy, opsgenie, pushover, rocketchat, script, slack, teams, telegram, twilio, webhook. `config` passed verbatim to Diun's `diun.yml` — option names + shapes preserved, so https://crazymax.dev/diun/notif/ is the schema reference. Empty default = stdout/logs-only (Loki still picks it up via the bundle's `loki_log_paths`).

**Recommended integration**: one `webhook` target pointing at the n8n bundle's new `diun-notification-router.json` workflow (`POST /webhook/diun-new-image`), then fan out from n8n to Slack / email / JSM. Mirrors the `grafana-alert-router` pattern. Workflow ships in `platform/apps/n8n/ansible/roles/n8n/files/workflows/`; consumers adapt the routing rules to their image namespace + severity preferences.

**Defaults**:
- `watch_schedule = "0 0 6 * * *"` — daily at 06:00 UTC, offset from backrest 02:00 and watchtower 04:00.
- `watch_by_default = true` — Diun watches every container on the host without per-container opt-in label, matching the plug-and-play philosophy. Flip false to require `diun.enable=true` labels.
- `default_watch_repo = false` — Diun only watches the exact tag in use, not every new tag ever pushed. "Tell me when MY tag has an update," not "tell me about every new tag."
- `watch_first_check_notif = false` — suppress the first-boot flood where every running container looks "new".
- `auto_update_enabled = false` on this bundle specifically. Auto-updating the tool whose job is to gate updates defeats the point.

**No Prometheus scrape** in v1. Diun doesn't expose `/metrics` natively — `crazy-max/diun-exporter` exists upstream but is experimental, not wired. `monitoring.prometheus_scrape_configs = []`; loki log paths only.

**No backup / no inbound / no public hostname / no Authentik**. Pure outbound-only host-service; local digest cache is rebuildable from a single registry sweep, not worth backing up.

**Watchtower deprecation**: Watchtower upstream is archived (last release Nov 2023, repo marked Maintenance Notice Dec 2025). Watchtower stays in fc for one more v2.x cycle — bundle untouched, consumer-template entry untouched, only the README gains a deprecation banner. v3.0.0 will drop watchtower. Consumers can migrate to diun (notify-only) or keep watchtower running until then — both ship in v2.13.0.

Bumped every `consumer-template/modules/stack/apps.tf` source ref from `v2.12.1` to `v2.13.0`. Regenerated `platform/ansible/apps.yml` (19 → 20 bundles).

---

## v2.12.2 — Fix split-dns vars-passthrough recursion in bootstrap.yml

`platform/ansible/bootstrap.yml` had a `vars: { split_dns_overrides: "{{ split_dns_overrides | default({}) }}" }` block on the split-dns role. When extra-vars didn't supply the key (e.g. fresh consumers whose `.ansible-vars.json` predates the v2.10.0 split-dns aggregation wiring), jinja recursed through itself and Ansible errored with "Recursive loop detected in template: maximum recursion depth exceeded."

Fix: drop the vars passthrough entirely. The role's `defaults/main.yml` has `split_dns_overrides: {}`; extra-vars / play vars override via Ansible's normal precedence chain.

Existing consumers whose `.ansible-vars.json` does carry the key see zero change.

---

## v2.12.1 — Remove postiz bundle

Postiz shipped briefly in v2.11.0 (~hours, before any consumer adopted it) and is removed per user direction: too AI-heavy. Mechanical reversal — bundle dir deleted, consumer-template module + aggregations dropped, apps-manifest entry removed, gen_apps_yml.py BUNDLES list trimmed. Bundle count: 19.

If you set `apps.postiz.enabled = true` in v2.11.0 tfvars (window was <1 hour), remove the block before bumping or terraform will error on the missing module. No state to migrate — postiz was never `apply`-ed in any documented consumer environment.

Postiz won't be re-pitched as a bundle. Consumers wanting social-media scheduling self-host outside fc.

---

## v2.12.0 — Full zabbix substitution: blackbox active probing + JSM contact point

Two pieces that closed the gap left when zabbix was dropped:

**1. Active liveness probing via `prom/blackbox-exporter`** (sidecar in the prometheus bundle, pinned `v0.28.0`). Was: prometheus only knew "did the in-network /metrics scrape succeed". Now: actually probes every public hostname over HTTPS from the prometheus host, exposing `probe_success`, `probe_http_status_code`, `probe_ssl_earliest_cert_expiry`, `probe_duration_seconds`.

- Contract growth: every bundle's `monitoring` output gains a `blackbox_targets = list(string)` field. Defaults: every HTTPS-facing app emits `["https://${var.hostname}/"]`; backend-only ones (loki, prometheus self, autoheal, watchtower, wazuh-agent) emit nothing. Nextcloud emits three entries (main UI / OnlyOffice / Talk HPB) and uses per-app health-endpoint paths instead of `/`. Grafana probes `/api/health`.
- Consumer-template aggregates the union into `local.aggregated_blackbox_targets` and passes to the prometheus module on a new `blackbox_targets` input. Bundle-local extras still accepted via the same input.
- New bundle vars: `blackbox_exporter_enabled` (default true — opt-OUT, plug-and-play), `blackbox_exporter_image_tag`, `blackbox_targets`. Sidecar is internal-only on `monitoring_internal`, port 9115.
- Ships paired `monitoring/dashboards/blackbox.json` + `monitoring/alerts/blackbox.yml` (`BlackboxProbeFailing` crit 3m, `BlackboxSslCertExpiringSoon` warn 14d / `VerySoon` crit 3d, `BlackboxProbeSlow` warn >5s 10m). Dashboards picked up via the existing `grafana_dashboards` aggregation; rules dropped into `/etc/prometheus/rules/` when the exporter is on.

**2. JSM (Jira Service Management Ops, heritage Opsgenie) as default Grafana alerting destination**. Native `opsgenie` contact point — no webhook-payload templating, JSM speaks the heritage Opsgenie alerts API directly.

- New grafana bundle vars: `jsm_api_key_secret_id` (Scaleway secret with `{"api_key": "..."}` — empty = JSM provisioning skipped entirely, existing behaviour preserved), `jsm_api_region` (`us` / `eu`), `jsm_priority_mapping` (Grafana severity -> JSM priority, default `critical=P1 warning=P3 info=P5`), `jsm_alert_tags`.
- Role renders `provisioning/alerting/contact-points.yml` + `policies.yml` when the secret ID is non-empty. Root notification policy targets `jsm-default`. When empty, both files are absent and Grafana uses its built-in default contact point.
- API URL: `https://api.atlassian.com/jsm/ops/integration/v1/alerts` (us) / `https://api.eu.atlassian.com/jsm/ops/integration/v1/alerts` (eu). Atlassian keeps shifting the JSM Ops paths around; the heritage `api.opsgenie.com` / `api.eu.opsgenie.com` endpoints still resolve too.
- **Behaviour shift on bump**: existing v2.11.0 consumers with grafana enabled but no `jsm_api_key_secret_id` set get zero behaviour change. Consumers who *do* set the var on bump start receiving JSM alerts immediately on next ansible run.
- The n8n `grafana-alert-router` workflow stays untouched. It remains the secondary path for slack/email/discord fan-out — operator wires it in as an additional contact point on Grafana's side if they want both.

Contract growth touches every bundle's `monitoring.tf`. Consumers re-applying do not need to change anything beyond the version bump — aggregation handles old (without `blackbox_targets`) and new shapes via `try()`.

---

## v2.11.0 — New bundle: Postiz (social media scheduling) + wazuh output doc fix

**New app bundle**: `platform/apps/postiz/` — social media scheduling + content management (https://github.com/gitroomhq/postiz-app, MIT). 5-container stack inside the bundle: postiz (web+api), redis, temporal, temporal-postgresql, temporal-elasticsearch. Postiz's main app DB lives on Scaleway RDB (the standard fc pattern); temporal's metadata DB stays bundled in-stack to avoid fighting Scaleway RDB's lifecycle for a glorified workflow store.

**Heavy footprint** — elasticsearch alone wants ~1GB RAM. Plan for ~3GB minimum allocated to the bundle. Not a fit for the smallest staging instances; document this when deciding `deployment_host_key` placement.

**Auth**: native OIDC via Postiz's generic-OAuth env vars (`POSTIZ_OAUTH_*`) → Authentik. Not forward-auth — Postiz has its own login UI that consumes OIDC tokens directly. Default `tier_access_level = "delegate"` — scheduling org social media is sensitive enough that the lowest tier shouldn't have access by default.

**Storage**: local filesystem only for v1 of this bundle. Postiz's generic-S3 PR (gitroomhq/postiz-app#1124) is still open upstream — only Cloudflare R2 + local are natively supported, and fc is Scaleway-only. Uploads live in the `postiz-uploads` docker volume; backed up by backrest. When Postiz adds S3 support, a follow-up wires it into Scaleway Object Storage with the standard `storage_class` toggle.

**Social-platform OAuth** (X, LinkedIn, Reddit, GitHub, Threads, Facebook, YouTube, TikTok, Pinterest, Dribbble, Discord, Slack, Mastodon, BeeBiive): 14 platforms supported via the `social_platform_credentials` bundle var. Consumer obtains keys from each platform's developer console out-of-band; bundle plumbs them through as scaleway secrets. Empty by default — Postiz silently omits unconfigured platforms. Per-platform env-var naming is upstream-inconsistent (X uses `X_API_KEY/X_API_SECRET`, BEEHIIV is spelled `BEEHIIVE_*` upstream, Discord has an extra `DISCORD_BOT_TOKEN_ID`) — bundle preserves the verbatim upstream spelling.

**Caveats**:
- Postiz exposes no native `/metrics` endpoint (verified). `monitoring.prometheus_scrape_configs = []` for v1.
- Healthcheck is a wget probe against the web port (Postiz's compose ships no native healthcheck); 120s `start_period` grace to avoid autoheal thrash during cold start.
- Temporal UI + spotlight/sentry sidecars from upstream's docker-compose are intentionally dropped — debug/admin convenience, not required.

Standard contracts implemented: `ansible`, `monitoring`, `backup_plan`, `split_dns_entries`, `required_inbound_rules`, `authentik_provider_id`.

---

**Drive-by fix**: `platform/apps/wazuh/terraform/outputs.tf` — `authentik_provider_id` output description was stale from before the v2.7.2 native-OIDC migration. Said "proxy-provider" + "Consumer MUST include in identity's extra_forward_auth_provider_ids" — both wrong. Wazuh uses native OIDC via opensearch-security; adding it to the forward-auth list would tell the embedded outpost to bind an OIDC provider it can't use. Behavior was already correct; only the doc misled.

---

## v2.10.3 — Bundle-level `storage_class` toggle on every bucket-creating bundle

Until now every Scaleway object bucket fc spins up was Standard Multi-AZ (€0.0146/GB/mo). For backrest specifically — a restic repository that's cold by definition — that was 6x too expensive vs the right tier.

`modules/infrastructure/storage/object_bucket/` grew two vars:
- `storage_class` — `STANDARD` (default, no rule), `GLACIER` (~6x cheaper), or `ONEZONE_IA` (~half, single-AZ)
- `storage_class_transition_days` — days an object lives in STANDARD before lifecycle rule transitions it (min 1)

Scaleway has no bucket-level storage class. When `storage_class != STANDARD`, the module creates a `lifecycle_rule` transitioning matching objects to the target class after the configured days. Every existing AND future object in the bucket gets moved once the rule fires.

All 5 bucket-creating bundles now expose `storage_class` + `storage_class_transition_days`:

| bundle | default | rationale |
|---|---|---|
| `apps/backrest` | **`GLACIER`** | restic data is cold by definition; ~83% bucket savings |
| `apps/nextcloud` | `STANDARD` | every user file read on download; hot |
| `apps/outline` | `STANDARD` | attachments load on every doc view |
| `apps/decidim` | `STANDARD` | public-facing uploads served inline |
| `apps/notifuse` | `STANDARD` | template/asset access pattern varies |

**Backrest behavior shift**: existing v2.10.2 backrest consumers bumping to v2.10.3 get a new lifecycle rule on their restic bucket. Existing snapshots auto-transition to GLACIER on the next rule evaluation (one day after upload). Restore latency on those snapshots goes from milliseconds to minutes/hours; restic operations that scan the repo (prune, check) will be slower. **If you actively rely on fast restic operations, set `apps.backrest.storage_class = "STANDARD"` to opt out before bumping.**

**Known limitation**: backrest's first-day-of-STANDARD-storage warm window before GLACIER transition could be eliminated by threading the class through restic's S3 upload options (`--option s3.storage-class=GLACIER`). Not wired in v2.10.3; deferred to a follow-up. Cost impact: 1 day of STANDARD per snapshot before the rule fires.

---

## v2.10.2 — `tier_names` cap raised from 4 to 12

The v2.10.1 refactor of `modules/authentik/tier-cascade/` capped `tier_names` at 4 entries (matched the default — the previous for_each implementation was unbounded above 2). Cap raised to 12 (10 reasonable tiers + 2 extras for one-offs). Additive: consumers with `tier_names.length <= 4` see zero diff; new tier_4..tier_11 slots have `count = 0` for them. No state migration, no plan churn for existing consumers. Validation loosened to 2-12.

Consumers actually wanting >4 tiers can now just extend `tier_names` past 4 entries. Anyone wanting >12 should be using RBAC roles, not nested groups.

---

## v2.10.1 — 5 peer-reported bug fixes

All five surfaced by the first consumer to exercise the v2.8+ stack end-to-end. No new features.

- **`platform/identity/terraform/outpost.tf`** — outpost resource was gated on `count = length(var.extra_forward_auth_provider_ids) > 0 ? 1 : 0`. When the list contained `(known after apply)` refs from compact()-ing yet-to-be-created bundle outputs (e.g., fresh-adding bentopdf + backrest_mgmt), terraform errored at plan with "Invalid count argument." Made unconditional — outpost is a singleton, no reason to gate.
- **`platform/apps/vikunja/terraform/variables.tf`** — default `oidc_groups_scope_name = "vikunja_scope"` isn't in Authentik's accepted scope vocabulary. Fresh vikunja deploys errored. Changed default to `"groups"` (Authentik's stock scope).
- **`platform/base/terraform/tem.tf`** — two bugs blocked `tem_enabled = true` (the default since v2.8.0):
  - `tem_subdomain_label = "@"` for zone apex. Scaleway DNS API rejects `@` and wants an empty string. SPF + DKIM + DMARC all hit it. Fixed via new `tem_subdomain_suffix` local that handles apex collapse.
  - SMTP port jsonencoded as integer. Scaleway secret schema validates as string end-to-end. Stringified to `"2587"`.
- **`modules/authentik/tier-cascade/`** — `authentik_group.tier` (for_each) with `parents = [authentik_group.tier[parent].id]` tripped Terraform's cycle detector. Refactored to 4 explicit `tier_0..tier_3` resources, count-gated by `tier_names` length. **Contract regression:** `tier_names` is now capped at 4 (was unbounded above 2). Consumers needing >4 tiers fork the module — the default's design intent was 4 from the start.

Consumers on v2.10.0 jumping to v2.10.1 get all five automatically. The tier-cascade refactor uses the same underlying Authentik group names, so existing state imports stay valid — but terraform will re-plan the cascade resources (different addresses internally). Expect a one-time apply that destroys + recreates the cascade groups under their new addresses. **If your existing cascade groups have UI-managed users you don't want lost, set `admin_user_pks` / `tier_extra_users` from terraform first, then bump.**

---

## v2.10.0 — Dynamic split-horizon DNS in base; multi-host topologies stop needing co-location

Until now, multi-host consumers had no answer for cross-host hostname resolution. Prometheus + Loki + Grafana had to co-locate on one host (the documented workaround); anything else meant editing scrape configs with private IPs by hand. That gap closes.

New plug-and-play primitive `split_dns_entries`. Every hostnamed bundle emits its `(hostname, private_ip)` pair. Consumer-template aggregates across enabled bundles into `split_dns_overrides`. New `platform/base/ansible/roles/split-dns/` runs on every host before docker — installs dnsmasq, tears down systemd-resolved's stub-listener cleanly, renders `/etc/dnsmasq.d/fc-split.conf` from the overrides map, points `/etc/resolv.conf` at dnsmasq. Cross-host requests for `loki.example.org` resolve to the management host's private IP instead of going out the public internet.

Auto-disables when `length(base.compute.hosts) == 1` — single-host topologies don't need it. Existing single-host consumers get no behavior change.

Bundles touched (each gained one new output): outline, steward, vikunja, bentopdf, notifuse, privacy-policy, nextcloud, decidim, jitsi, espocrm, n8n, backrest, grafana, wazuh. Nextcloud emits 3 entries (collabora + onlyoffice + talk-hpb hostnames). No input variables added anywhere.

Two overridables on the role for non-standard topologies: `split_dns_docker_bridge_ip` (default `172.17.0.1`) for hosts running a custom docker `bip`, and `split_dns_allowed_cidr` (default `172.16.0.0/12`) for VPCs on 10.0/8 instead. UFW allow on port 53 from the configured CIDR.

Grafana + prometheus READMEs softened: co-location is no longer the only option. ARCHITECTURE.md plug-and-play table picks up the new output.

No contract breaks. Consumers on v2.9.3 jumping to v2.10.0 get split-DNS automatically on next bootstrap run, gated on host count.

---

## v2.9.3 — Ansible-runner image, grafana picks up bundle dashboards, TF↔Ansible boundary doc

Three landings, no contract breaks.

**Ansible runner image** — `.github/workflows/runner-publish.yml` publishes `ghcr.io/sheyaln/sabokit-runner:<tag>` on every `v*` tag. Bakes ansible-core + the four collections (`community.docker`, `community.general`, `ansible.posix`, `scaleway.scaleway`) + the whole `platform/` tree. Consumers stop installing ansible locally and run `docker run --rm -v $PWD/env:/env:ro runner:vX site.yml -i /env/inventory.ini -e @/env/enabled_apps.json`. `:latest` rolls forward only on clean `vN.N.N` pushes — backports via `workflow_dispatch` get the explicit tag only. See `docker/runner/README.md`. Same path `sabokit-manager` will shell out to.

**Grafana dashboard pickup** — every bundle's `monitoring.grafana_dashboards` output now actually reaches Grafana. Consumer-template aggregates contributions across bundles into `local.aggregated_grafana_dashboards`, passes them as `grafana_dashboards = list(object({ filename, contents }))` into the grafana bundle, and the role's new `Provision aggregated dashboards` task writes each entry under `{{ grafana_install_dir }}/provisioning/dashboards/`. File provider polls every 30s — no restart needed. TEM dashboard from v2.9.1 finally lands somewhere visible.

Drive-by fixes that came with that:
- `apps/prometheus` gained `monitoring.tf` + `output "monitoring"` — the TEM dashboard JSON had been on-disk since v2.9.1 with no contract output exposing it.
- `apps/steward` gained the `monitoring.tf` + `output "monitoring"` it was missing (had `monitoring_enabled` var, no output). Blocked `terraform validate` against the consumer module. Empty contribution placeholder for now.

**TF↔Ansible boundary doc** — new `## Terraform vs Ansible` section in `ARCHITECTURE.md`. Names the split: TF owns cloud + API state; Ansible owns convergent host-side execution. Bridge is the per-bundle `output "ansible"` map. Section covers the rule, the bridge contract with a real snippet, a three-question deciding test for new things, the failure modes when you cross the line, and the Scaleway Secret Manager edge case (TF writes, Ansible reads at deploy time).

No vars to add, no migrations. Consumers running `consumer-template/scripts/bump-version.sh v2.9.3` get the grafana wiring on next apply.

---

## v2.9.2 — File Integrity Monitoring on by default for `apps/wazuh-agent`

The `wazuh-agent` bundle now ships FIM enabled out of the box: a custom `ossec.conf` is mounted at `/wazuh-config-mount/etc/ossec.conf` (full override of the image's auto-config) with `<syscheck>` enabled on the standard sensitive paths, plus host `auditd` rules dropped at `/etc/audit/rules.d/wazuh.rules` and `/var/log/audit/` bind-mounted into the container so the agent's `localfile` reader tails `audit.log`.

Defaults cover: `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`(.d), `/etc/pam.d`, `/etc/ssh/sshd_config`(.d), `/root/.ssh`, the full cron tree (`/etc/crontab`, `/etc/cron.{d,hourly,daily,weekly,monthly}`, `/var/spool/cron`), `/etc/hosts`, `/etc/resolv.conf`, systemd units (`/etc/systemd/system`, `/lib/systemd/system`), `/etc/docker/daemon.json`, plus syscheck-only coverage of `/boot`, `/usr/bin`, `/usr/sbin`, `/bin`, `/sbin`. See `platform/apps/wazuh-agent/README.md` for the full list + the default exclusions.

New TF vars on the `wazuh-agent` bundle:
- `fim_enabled` (default `true`) — master FIM toggle. Set `false` if you ship FIM another way.
- `fim_extra_paths` (default `[]`) — extra absolute paths to monitor (added to both auditd rules and syscheck).
- `fim_extra_exclusions` (default `[]`) — extra `<ignore>` entries for syscheck.

Behavioural notes:
- `rootcheck` stays disabled (history of false positives + load), `syscheck realtime="yes"` is restricted to small config dirs (`/etc/ssh`, `/etc/sudoers.d`, `/etc/pam.d`) to avoid inotify exhaustion, and `syscollector scan_on_start` is off — these patterns have crashed managers in the past.
- The role gates auditd rule rendering on `/etc/audit/rules.d` existing; if `auditd` isn't installed on the host, syscheck still runs, only the kernel-sourced `-w` events are missed (debug warning is emitted).
- The handler runs `augenrules --load` then restarts `auditd` when rules change.

No breaking changes — existing consumers get FIM automatically on the next ansible run. To opt out: set `fim_enabled = false` on the bundle.

---

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
