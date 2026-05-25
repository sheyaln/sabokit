# Changelog

All notable changes to sabokit go here. Versioning follows semver; major bumps signal breaking contract changes for consumers.

## v2.18.2 — 2026-05-25

Critical safety fix for state-import flows. Without this, importing existing `scaleway_secret_version` resources triggers a destroy+recreate on next apply because the Scaleway API doesn't return the `data` attribute on read — every refreshed `random_password` ends up looking like a forces_replacement diff.

### Fixed
- **`lifecycle { ignore_changes = [data] }` added to every `scaleway_secret_version` that writes computed values.** Covers oidc-app credentials, saml-app credentials, every per-app database secret (postgres / postgres_database modules), identity_bootstrap database secret, TEM credentials, and every app-bundle secret_version. Side effect: rotating the underlying `random_password` no longer auto-rolls the secret_version on apply — taint the resource explicitly to rotate.

### Migration
- Consumers mid-state-import: this fix lets `terraform plan` stop showing force-replace on imported secret_versions. Re-plan after the bump; expect the destroys to disappear.

## v2.18.1 — 2026-05-25

Two staging-stand-up UX fixes peer flagged from a fresh DEV1-M cutover.

### Fixed
- **Authentik health-poll window widened from 5min → 15min.** `authentik_health_retries` default raised 30 → 90 (10s delay unchanged). First-boot Postgres migrations on smaller Authentik tiers (DEV1-M) take ~6-7min; the prior 5min window expired before health pass, ansible failed, and `authentik-worker` never started. Steady-state restarts still return in <30s; the wider window only matters for cold first-boot.
- **`configure.sh` terraform apply defaults to `-parallelism=3`** (was terraform's default 10). Small Authentik tiers can't keep up with 10 concurrent API calls during the initial flows/bindings/stages create — cascade of 503/502 and ~30+ resource failures. Override for beefier deployments: `TF_PARALLELISM=10 ./configure.sh`.

## v2.18.0 — 2026-05-25

Tier model now expresses a partial-order DAG instead of a linear cascade. Replaces `tier_names` / `tier_keys` with `tier_slots`.

### Breaking
- **`tier_names`, `tier_keys`, `tier_names_override`, `tier_keys_override`, `treasurer_group_name` removed; replaced by `tier_slots`.** The linear-cascade shape was insufficient for orgs with parallel-peer ranks (e.g. multiple L3 officers each owning their own scope; equal-rank L4 admins). `tier_slots` expresses each rank as a slot holding one or more independent peers; an app scoped to a peer admits that peer's own group plus every group in every strictly-higher slot. In-slot peers do NOT bridge — they are equal-rank but independent.
- **`modules/authentik/tier-cascade/` deleted.** Identity layer now owns cascade composition directly; the per-slot tier resources live in `platform/identity/terraform/user_groups.tf`.
- **Bundle `tier_access_level` semantics shifted from tier_name to peer_name.** Lookup pattern (`var.base.authentik.tier_cascade[var.tier_access_level]`) is unchanged; only the meaning of the string changes. Defaults across every cascade-enabled bundle moved to `"admin"` (the one peer_name we mandate exists in tier_slots).
- **`base.authentik.tier_cascade` output shape:** outer key changed from tier_key to peer_name; inner map (group_name → group_id) unchanged.

### Required consumer change
Set `var.identity.tier_slots` in your root tfvars — the variable is required, no default. See the new `tier_slots = [...]` block in `consumer-template/environments/_template/terraform.tfvars.example` for a generic L1-L4 example. The `admin_group_name`, `member_group_name`, `delegate_group_name` named pointers stay; they must reference a group_name that exists somewhere in tier_slots.

### Migration
- Replace any `tier_names_override = [...]` / `tier_keys_override = [...]` with `tier_slots = [{ name, peers = { ... } }, ...]`.
- For the old default four-tier shape, use:
  ```
  tier_slots = [
    { name = "l1", peers = { member = "member" } },
    { name = "l2", peers = { delegate = "delegate" } },
    { name = "l3", peers = { treasurer = "treasurer" } },
    { name = "l4", peers = { admin = "admin" } },
  ]
  ```
- For parallel peers, add more entries to a slot's peers map. Example:
  ```
  { name = "l3", peers = { treasurer = "union-treasurer", comms = "comms-officer", organizing = "organizing-liason" } }
  ```

## v2.17.0 — 2026-05-25

Consumer-facing wrapper around the runner image + a working secret-rotation path. Stop telling consumers to clone the repo.

### Added
- **`scripts/sabokit-runner.sh`** — friendly bash wrapper around `ghcr.io/sheyaln/sabokit-runner`. Flags: `--apps`, `--servers` (alias `--hosts`), `--base`, `--no-base`, `--rotate-secrets`, `--check`, `--overlay`, `--inventory`, `--enabled-apps`, `--env`, `--image`, `--dry-run`, `--verbose`. Bash 3.2 compatible. Image tag defaults to the wrapper's own version; pin via `--image`. Recipe table front-and-center in `docker/runner/README.md` + raw `docker run` equivalent below for transparency.
- **`[secrets]` tag across 14 app roles** (backrest, broadsheet, decidim, espocrm, grafana, jitsi, n8n, nextcloud, notifuse, outline, prometheus, steward, vikunja, wazuh). 70 tasks tagged in total — Scaleway secret-ID normalization, `lookup()` fetches, SMTP-config defaults, env-file renders, secret-bearing config renders. `sabokit-runner --rotate-secrets` (or `ansible-playbook --tags secrets`) re-runs the secret path only; restart handlers fire when env content changes. Convention documented in `platform/ansible/README.md`.

### Notes
- Per-app secret rotation via `--rotate-secrets --apps X` is union semantics, not intersection — runs both all-secrets AND all-of-X. For genuine per-app rotation, run `--apps X` directly: the full role is idempotent and re-fetches secrets along the way (seconds-fast).
- Consumer overlays: `--overlay DIR` mounts at `/consumer:ro`, prepends `/consumer/roles` to roles path (upstream still wins on conflict), auto-runs `DIR/extensions.yml` after upstream's `site.yml` if present. No `import_playbook` gymnastics — both playbooks run in one ansible process for shared facts/SSH.
- Espocrm OIDC bootstrap, decidim post-deploy migrations, and a couple of other rotation-incompatible task types intentionally left untagged — those need full role runs because secret changes flow through `docker exec` paths or one-shot DB migrations rather than env reload.

## v2.16.2 — 2026-05-25

Broadsheet bundle defaults were wrong out of the box.

### Fixed
- **Broadsheet image default corrected** from `ghcr.io/sheyaln/sabokit-broadsheet` to `ghcr.io/sheyaln/broadsheet` (the actual published stream). Same fix in `consumer-template/apps-manifest.yaml`.
- **`build_from_source` default flipped from `true` to `false`.** The published image is the supported path; source-build is opt-in for unreleased fork patches only. Saves ~3 min on first deploy + drops a hard dep on a host-side toolchain.

## v2.16.1 — 2026-05-25

Two consumer step-3 blockers, both terraform-locals errors before any imports/refresh.

### Fixed
- **`tier_cascade` decoupled from group display names.** Output is now keyed by stable logical identifiers (`tier_keys`), not `tier_names`. Any consumer overriding `*_group_name` (or `tier_names_override`) was hitting `Invalid index` on `tier_cascade[var.tier_access_level]` across every hardcoded-tier bundle. Default consumers unaffected — `tier_keys` defaults to `tier_names`. Identity layer auto-derives logical keys from the four named knobs (`member_group_name` → `"member"`, etc.). Consumers using `tier_names_override` should also set the new `tier_keys_override` if their bundles' `tier_access_level` expects logical keys.
- **`prometheus` scrape_configs aggregation normalizes per-bundle entries.** Bundles can omit `scheme` / `metrics_path` / per-target `labels`; the consumer-template aggregator defaults them and casts labels to `map(string)`. Fixes `all list elements must have the same type` when 2+ bundles with prometheus_scrape_configs are enabled together. New bundles using non-static-SD scrape entries (file_sd, dns_sd) will need aggregator updates — none currently do.

## v2.16.0 — 2026-05-25

### Added
- `platform/apps/broadsheet/` — new bundle, sabokit-broadsheet fork of notifuse. Defaults: image_source_repo = sheyaln/sabokit-broadsheet, image_source_ref = main, icon = broadsheet-icon.png, application_name = Broadsheet.
- consumer-template + apps-manifest wiring for broadsheet alongside notifuse.

### Deprecated
- `platform/apps/notifuse/` — replaced by broadsheet. Stays through one more v2.x cycle for migration headroom; v3.0.0 will drop it. Notifuse README has a deprecation banner.

## v2.15.7 — `icon_base_url` platform default + per-bundle `icon_filename`

App icons stop being a per-consumer plumbing problem. New `identity.var.icon_base_url` (default `https://raw.githubusercontent.com/sheyaln/sabokit-assets/v1.0.0/application-icons`) surfaces on `var.base.authentik.icon_base_url`. Every bundle composes `${icon_base_url}/${icon_filename}` when no full URL override is set.

**Per-bundle resolution:**
1. `var.icon_url` non-empty → used verbatim (full URL override).
2. else `var.icon_filename` non-empty → `${base.authentik.icon_base_url}/${icon_filename}`.
3. else empty (no icon — lower modules then substitute `default-logo.png`).

**13 bundles get `icon_filename`** (bentopdf, decidim, espocrm, grafana, jitsi, n8n, nextcloud, notifuse, outline, steward, vikunja, wazuh, backrest). `icon_url` semantic shifts from "Authentik media path" to "full URL override"; default `""` (was `null` for most).

Defaults match canonical filenames in sabokit-assets v1.0.0 where available:

| bundle | `icon_filename` default |
|---|---|
| bentopdf | `bentopdf-icon.png` |
| decidim | `decidim-icon.png` |
| espocrm | `espocrm-icon.png` |
| grafana | `grafana-icon.png` |
| n8n | `n8n-icon.png` |
| outline | `outline-icon.png` |
| steward | `steward-icon.png` |
| vikunja | `vikunja-icon.png` |
| jitsi, nextcloud, notifuse, wazuh, backrest | `""` (no canonical asset; opt in by overriding) |

**Behaviour shift on bump.** Bundles with a non-empty default (bentopdf, decidim, espocrm, grafana, n8n, outline, steward, vikunja) gain an icon by default where previously they had none. Authentik plan will show `meta_icon` flipping from `default-logo.png` to the sabokit-assets URL. Cosmetic-only, but visible in the plan diff for these 8 bundles. To silence: pin `apps.<bundle>.icon_filename = ""`.

**Bookmark module** (`modules/authentik/bookmark/`) gains the same shape: `icon_url` + `icon_filename` + new `icon_base_url` input. Callers pass `var.base.authentik.icon_base_url` through.

**OnlyOffice (nextcloud sub-component).** Skipped — OnlyOffice has no separate authentik application/bookmark, it's a backend service Nextcloud talks to. Same for Talk HPB. No icon surface to set.

**Consumer overrides.** Per-app: `apps.<bundle>.icon_filename = "custom.png"` or `apps.<bundle>.icon_url = "https://my-cdn/app.svg"`. Whole platform: `identity.icon_base_url = "https://icons.internal.example.org/v2"` retargets every default-filename lookup at your own CDN / internal mirror in one shot.

Consumer-template `apps.tf` + `apps-manifest.yaml` updated alongside. `terraform fmt -recursive` clean, all bundles + identity + bookmark `terraform validate` clean, `python3 scripts/gen_apps_yml.py --check` clean. No state migration beyond the cosmetic `meta_icon` shift on the 8 bundles above.

---

## v2.15.6 — Service-account extra-groups via generic identity.extra_groups

Peer asked for hardcoded `union-automation` + `union-cloud-admin` groups in upstream + default n8n service-account membership in those groups. fc target audience is broader than unions (cooperatives, mutual aid networks, decentralized political orgs, faith-based commons) — `union-*` lexicon excludes them. Counter-shipped as a fully generic primitive.

**`identity.var.extra_groups` already existed** (map of `{name -> {is_superuser, description}}`). What was missing: the consumer-template didn't surface it. Added `var.identity` to `consumer-template/modules/stack/`, passed through to the identity module as `extra_groups = try(var.identity.extra_groups, {})`. Consumers now set their org-specific groups in tfvars:

```hcl
identity = {
  extra_groups = {
    "union-automation"  = { description = "Service-account scope for automation workers acting on behalf of the union." }
    "union-cloud-admin" = { description = "Service-account scope for cloud-resource administration on behalf of the union." }
  }
}
```

Coops set `coop-*`. Mutual aid networks set `mutual-aid-*`. Whatever fits the org's lexicon. No upstream contamination.

**`var.service_account_extra_groups`** added to n8n + steward bundles (default `[]`). Service account membership becomes `[authentik Admins] ∪ [for g in var.service_account_extra_groups : var.base.authentik.groups[g]]`. The named groups must exist in `var.base.authentik.groups` — typically created via identity's `extra_groups`.

```hcl
apps.n8n.service_account_extra_groups = ["union-automation", "union-cloud-admin"]
```

Steward's bundle exposes the same knob for parity (steward's bearer-token API access through the admins group is usually sufficient, but the knob lets a consumer scope it down for custom authz models).

No state migration. Existing consumers see no diff — defaults are empty everywhere.

---

## v2.15.5 — n8n env.j2 propagation gap for AUTHENTIK_API_URL/TOKEN

v2.15.3 added `AUTHENTIK_API_URL` + `AUTHENTIK_API_TOKEN` to the n8n app secret bag in `secrets.tf` but missed the propagation step — `env.j2` never read them. Result: keys sat in Scaleway Secret Manager but the n8n container had nothing in `process.env` for workflows that talk to Authentik. Peer caught it during v2.15.3 consumption audit.

Fix: two lines added to `platform/apps/n8n/ansible/roles/n8n/templates/env.j2` next to the existing OIDC block. Defensive `| default('')` so pre-v2.15.3 secret bags (which won't have the keys) don't break the template render — useful for consumers who haven't tainted `scaleway_secret_version.app[0]` yet to pick up the new bag shape.

Steward's `env.j2` was already correct (the original v2.13.x scaffolding propagated those keys end-to-end). The gap was n8n-only.

---

## v2.15.4 — `application_slug` override across 12 bundles

**Additive override for the Authentik application's slug.** Legacy consumers cutting over to fc bundles can't carry their existing Authentik state forward without this: bundles hardcoded the application slug to the bundle's stock name (`outline`, `nextcloud`, ...), and renaming the slug live breaks Authentik's `issuer_mode = per_provider` OIDC discovery URL — the URL embeds the slug, every connected app reauths. New `application_slug` knob lets the consumer pin the slug to the legacy value at import time.

Concrete case: a consumer with a branded `sabo-cloud` Authentik application wants to import its state into the fc `nextcloud` bundle. Pre-v2.15.4 the bundle would force-replace the application to `nextcloud`. Now: set `application_slug = "sabo-cloud"` in the apps tfvars and the existing application imports clean.

**Bundles touched (12):** bentopdf, decidim, espocrm, grafana, jitsi, n8n, nextcloud, notifuse, outline, steward, vikunja, wazuh.

**`local.slug` left alone — new `local.application_slug` introduced.** `local.slug` feeds ~20 internal namespaces per bundle: bucket names, secret names, IAM application names, database names, backup plan IDs, monitoring labels, service-account usernames. Hijacking it would rename every one of those for `nextcloud → sabo-cloud` and trigger destroys on each. Instead the new local is scoped — it ONLY feeds the authentik application's slug and any URL that's keyed by that slug (OIDC issuer / discovery / end-session / jwks endpoints in `secrets.tf` and a handful of bundle-specific URL locals). Internal namespaces stay on `local.slug` and are unaffected.

**Backrest skipped.** Backrest's authentik call already uses `local.qualified_slug` (a per-instance value like `backrest-mgmt`, `backrest-tools`). Per-instance qualification makes legacy slug collisions much less likely — no two consumers are realistically going to share a `backrest-mgmt` legacy slug across orgs. Lower priority, not blocking the immediate cutover. Future work if a real collision surfaces.

Additive change, default empty = existing consumers see no behaviour change. Consumer-template `apps.tf` + `apps-manifest.yaml` updated alongside the bundles. No state migration.

---

## v2.15.3 — Service-account `username = email` + n8n service account + EspoCRM category

**Service-account convention completed.** v2.15.1 shipped the `service_<thing>` resource name + `svc-<thing>` username/email pattern but left username and email *inconsistent* with each other (username = `svc-steward`, email = `svc-steward@<domain>`). v2.15.0 established the "username = email always" invariant for human users via the user-settings sync policy. Service accounts now match — `username = email = svc-<thing>@<base_domain>`.

- **steward**: `authentik_user.service_steward.username` flipped from `svc-steward` to `svc-steward@<base_domain>`. In-place attribute update, no destroy.
- **n8n** (new in v2.15.3): added `authentik_user.service_n8n` + `authentik_token.service_n8n`. Same shape as steward — username = email = `svc-n8n@<base_domain>`, member of `authentik Admins`, non-expiring API token. Token exposed in the n8n app secret bag as `AUTHENTIK_API_TOKEN` for workflows that need server-to-server Authentik access. `AUTHENTIK_API_URL` also surfaced.

**Caveat on n8n secret bag update**: `scaleway_secret_version.app` has `lifecycle { ignore_changes = [data] }` to avoid version churn from OIDC client_secret rotation. Adding the new `AUTHENTIK_API_TOKEN` key to the data block won't trigger a version refresh on bump. Consumers wanting the new token surfaced in the secret bag must `terraform taint module.n8n.scaleway_secret_version.app[0]` once after bumping to v2.15.3. The token resource itself is created cleanly; only its propagation into the bag needs the taint.

**EspoCRM category default `Tools` → `Administration`.** CRM is where org admins manage member data — same bucket as steward, not the same as a PDF editor. Also fixed a pre-existing drift between the TF default (`Tools`) and the apps-manifest default (`Productivity`) — both now `Administration`.

No state migration beyond what's documented above. The username flip is in-place; n8n's new resources land cleanly; espocrm's category change is metadata only.

---

## v2.15.2 — Manual enrollment MFA-before-terminal + release automation

**Bug fix — manual enrollment forced MFA into a dead path.** `flow_manual_enrollment.tf` bound the welcome message at order 35 and MFA setup at order 40 — MFA fired AFTER the terminal screen. Worse: the welcome HTML's JS submit-interceptor (`preventDefault()` → `window.location='/'`) made the welcome a terminal stage even after order swap. Active users (re-entering the enrollment flow post-activation) would get bounced to `/` before ever reaching MFA setup or `user_login`.

Fix:
- swapped binding orders — `manual_enrollment_mfa_setup_binding` now at 35, `manual_enrollment_welcome_binding` at 40.
- gated welcome on `shared_inactive_user_gate` (same policy v2.15.0 added to the auth flows). Active users skip the stage entirely and proceed to user_login at 100. Inactive users still hit the welcome, then JS bounces them to `/` (correct terminal behavior for accounts pending delegate activation).

No state migration — the binding-order changes are in-place updates, no resource renames. New `authentik_policy_binding.manual_enrollment_welcome_inactive_gate_binding` resource gets created on first apply.

**Release automation: `scripts/release.sh`.** Replaces the manual `perl -pi -e` + `git tag` + `git push` dance every recent patch has done. Validates pre-conditions (on master, tag doesn't already exist, CHANGELOG has an entry for the tag), bumps every `?ref=` in `consumer-template/modules/stack/`, commits a `chore(consumer-template): bump refs to <tag>` commit, tags master tip with the CHANGELOG entry title, pushes master + the tag. Doesn't write the CHANGELOG (that's the release author's job before invoking) and doesn't touch `consumer-template/scripts/bump-version.sh` (that's the consumer-side tool, different concern).

Usage:
```
./scripts/release.sh v2.15.3
```

Fails loudly if on the wrong branch, the tag exists, the CHANGELOG entry is missing, or residual non-target refs remain in the stack module.

---

## v2.15.1 — Service-account naming convention

Platform convention for service accounts going forward:
- **TF resource name**: `service_<thing>` (snake_case)
- **Username + email**: `svc-<thing>` (kebab-case)

Not the opposite of either.

**Steward** (only Authentik service account fc ships today):
- `authentik_user.service_account` → `authentik_user.service_steward`
- `authentik_token.service_account` → `authentik_token.service_steward`
- username + email: `steward-svc` → `svc-steward`
- `moved {}` blocks on both resources — existing consumers' state migrates in-place. No destroy+recreate, the API token stays valid, the username/email flip happens as an in-state attribute update.
- output renamed: `service_account_token_secret_hint` → `service_steward_token_secret_hint`. Anyone reading the old output name in tfvars or downstream automation bumps the reference.

**n8n** (no Authentik service account in fc TF — only the Authentik group):
- README's Nextcloud-admin credential row now documents the manual `svc-n8n` Nextcloud user setup the `nextcloud-form-edit-access-notifier` workflow expects. Nextcloud users aren't fc-TF-managed, so this is a consumer setup step — flagged so it isn't a surprise on first form-submit.

No other service accounts in the tree as of v2.15.1. Future ones follow the same convention.

**Drive-by ref pin fix**: `consumer-template/modules/stack/base.tf` had its source ref pinned at `v2.8.1` since the cycle-bug ship — same pre-existing wiring gap that v2.14.2 fixed for `identity.tf`/`identity_bootstrap.tf`. Bumped to `v2.15.1`. Consumers now pick up the v2.10.1 TEM DNS apex + SMTP port-stringify fixes + v2.10.0 split-dns role + v2.8.0 TEM domain creation. All these were already on master but invisible to consumers who only bumped the apps.tf refs.

---

## v2.15.0 — Authentik identity UX: four enrollment + edit-info + inactive-user changes

Four additive identity-bundle changes. Bundle output shape unchanged — `base.authentik.flows.user_settings_flow` still a UUID string, every other flow UUID/group key/sources entry untouched. OIDC + forward-auth providers see no contract diff. The custom user-settings flow's UUID is a new value (replacing Authentik's built-in `default-user-settings-flow` UUID), so any consumer that pinned the old default-flow UUID outside `var.base.authentik` needs to bump its reference — none of the in-tree bundles do.

**1. User-settings flow cloning Authentik's default minus username.** New `authentik_flow.user_settings` (slug `user-settings`) replaces Authentik's built-in default. Same prompt shape Authentik ships (`name`, `email`, `locale`) minus the username field — username is hidden because change 2 makes it equal to email anyway, and exposing it would let users break that invariant. Password change + delete account stay as separate flows triggered by buttons in Authentik's user-settings UI via `brand.tf`'s `flow_recovery` + `flow_unenrollment` (no change there). The flow's UUID flows out via the new `module.flows.user_settings_flow_uuid` output; `brand.tf:24` and `outputs.tf:38` both point at it. The bundle's `default_user_settings_flow_id` data-source output is kept for back-compat (nothing currently references it).

**2. Username locked to email on edit-info.** The user-settings flow's user_write stage binds a new `policy-user-settings-sync-username-to-email` policy that copies `prompt_data['email']` into `prompt_data['username']` pre-write. Same shape as the existing `policy-manual-enrollment-set-username-from-email` policy on the manual enrollment flow — atomic write, both fields persisted together.

**3. Social enrollment prompts for name + member_id.** New stage `authentik_stage_prompt.source_enrollment_profile` binds between AUP and user_write on the source-enrollment flow (order 7). Two fields:
- The existing `authentik_stage_prompt_field.manual_enrollment_name` field, reused directly so social enrollees see the same naming prompt as manual enrollees (`field_key = "name"`, label `"Chosen Name"`, required text).
- A new `member_id` field (optional text, label overridable via new bundle var `member_id_label`, default `"Member ID"` — attribute key stays `member_id` always so downstream automations don't break per-consumer).

The `policy-source-enrollment-user-setup` expression drops the old `user_email.split('@')[0]` username derivation: username is now `user_email` unconditionally, `user.name` comes from the prompt's `name` field, and `member_id` flows through prompt_data so user_write stores it in `user.attributes['member_id']` (only when the user filled the field — empty strings get stripped pre-write so we don't persist `""`). Defensive OAuth-name fallback fires only if the (required) prompt somehow returned empty.

**4. Inactive-user gets a full-page message instead of a silent failure.** New shared static prompt stage `authentik_stage_prompt.shared_inactive_user` carries an HTML message (`assets/inactive-user-message.html.tpl` — adapted from the enrollment welcome template, different framing: "reach out to a delegate to reactivate" vs the enrollment "reach out to a delegate to activate"). Bound on both auth flows that can reach `user_login`:

- `authentication_flow_username_and_passkey` — order 35, between MFA validate (30) and user_login (40)
- `source_authentication` — order 5, before user_login (10)

A new policy `policy-shared-inactive-user-gate` gates both bindings — returns True (show the stage) only when `pending_user.is_active == False`. Active users skip the stage entirely. After the message, the existing user_login stage runs and refuses to log an inactive user in — natural login failure, but the user saw the message first.

**New bundle variable:** `member_id_label = string` (default `"Member ID"`) — display label for the optional member-id field on the social enrollment flow. Attribute key not affected.

---

## v2.14.3 — Stagger authentik policy_binding order to avoid API uniqueness collision

Peer-reported correctness bug surfaced during DCIWW prod cutover. Four `modules/authentik/` helper modules — `bookmark`, `oidc-app`, `saml-app`, `traefik-forward-auth` — hardcoded `order = 10` on their `for_each` `authentik_policy_binding "authorized"` resources. Authentik's API enforces uniqueness on `(policy, target, order)` for UPDATE; the second binding onward errors with `HTTP 400 "The fields policy, target, order must make a unique set"` once `authorized_groups` has more than one entry. Worse: the API rejects roll-back from the partial-apply state because the same constraint blocks both directions.

Fix: `order = 10 + index(keys(var.authorized_groups), each.key)` — lex-ordered key index gives each binding a distinct slot. Deterministic across applies; no migration. Existing consumers whose `authorized_groups` only had one entry see no diff.

Affects every consumer using >1 `authorized_groups` on any of the four helper modules. Most existing fc app bundles pass cascade-derived authorized_groups via the tier-cascade module, which can produce 2-12 entries depending on `tier_access_level`.

---

## v2.14.2 — Close stale identity ref pin in consumer-template

`consumer-template/modules/stack/{identity.tf,identity_bootstrap.tf}` had their source refs pinned at `v2.8.1` since that tag's cycle-bug ship — never bumped along with subsequent identity work. v2.14.1 was supposed to bump them; the perl edit landed after the branch commit and missed the merge. Shipping as a one-line patch.

Consumers bumping consumer-template ref from `v2.14.1` (or earlier) to `v2.14.2` now pick up every v2.9+ identity change: v2.10.1's tier-cascade refactor + outpost count-unknown fix, v2.14.1's activation race + webhook attr filter.

---

## v2.14.1 — Identity policy fixes: activation race + webhook attr filter

Two policy-template fixes that were sitting as WIP in the working tree all session — taken to ship.

**1. Activation double-fire race** (`platform/identity/terraform/expressions/policy-user-activation-notification.py.tpl`). Authentik fires multiple `model_updated` events in quick succession when a user is activated — the activation save itself plus auxiliary writes (last_login bumps, group syncs). The previous naive `attributes.get("activation_notification_sent")` idempotency check races: both invocations pass, the workflow fires twice, admins get duplicate emails per activation.

Replaced with an atomic `select_for_update()` row lock: open a transaction, lock the user row, re-check the flag inside the lock, claim it BEFORE doing the notification work, commit. Reserve-then-do (at-most-once). Trade-off documented inline — a rare missed notification on transient failure beats spamming admins on every activation.

**2. Webhook attribute filter** (both policy templates). Internal bookkeeping attribute keys (`activation_notification_sent`, `enrollment_notification_sent`, `signup_correlation_id`, `signup_method`) were leaking into the webhook payload's `user.attributes` field. Downstream automations had to filter them out themselves. Now filtered at the policy boundary; webhook payload's new `attributes` field carries only consumer-supplied per-user metadata.

**Consumer-template identity refs bumped** from `v2.8.1` to `v2.14.1`. Pre-existing wiring gap — both `consumer-template/modules/stack/identity.tf` and `identity_bootstrap.tf` had been frozen at v2.8.1 since the cycle-bug ship, skipping the v2.10.1 tier-cascade refactor + outpost count-unknown fix and other v2.9+ identity work. Bumping along with this patch picks up everything consumers should already have had.

---

## v2.14.0 — backrest `backup_plan` content-intelligence + pre/post hooks

`backup_plan` grew from "list of paths" to a content-aware shape. Bundles now declare WHAT they care about — `/opt/<slug>` (bind-mount data) and/or specific named docker volumes — and the backrest role translates that into restic paths at render time. Old shape (`paths` + `excludes`) still accepted unchanged; the role merges both, so a consumer holding back on a bundle bump keeps working.

**New `backup_plan` shape (per bundle):**

```hcl
backup_plan = (var.enabled && var.backup_enabled) ? {
  id               = local.slug
  paths            = ["/backup-sources/opt/${local.slug}"] # legacy field; kept for backward compat
  opt_dir          = true                                  # back up /opt/<id>
  volumes          = ["nextcloud-data"]                    # named docker volumes -> /backup-sources/docker-volumes/<v>/_data
  excluded_volumes = ["redis-data"]                        # documentation today; future per-volume retention hook
  extra_paths      = []                                    # one-off restic paths
  pre_hooks        = []                                    # host shell, wrapped as CONDITION_SNAPSHOT_START actionCommand, on_error=CANCEL
  post_hooks       = []                                    # host shell, wrapped as CONDITION_SNAPSHOT_END actionCommand, on_error=IGNORE
  excludes         = []
  schedule         = { cron = var.backup_schedule_cron }
  retention        = var.backup_retention
} : null
```

**Backrest role translation** (`platform/apps/backrest/ansible/roles/backrest/templates/config.json.j2`): effective restic `paths` per plan = union of legacy `paths`, `["/backup-sources/opt/<id>"]` if `opt_dir`, `["/backup-sources/docker-volumes/<v>/_data" for v in volumes]`, and `extra_paths`, deduped. `pre_hooks` / `post_hooks` render as entries in the plan's `hooks[]` array — Backrest's `Hook` proto with `actionCommand.command = <string>`. Restic skips paths that don't exist on a given host, so passing the full union to every backrest instance is the same plug-and-play pattern as `required_inbound_rules` — backrest on `apps` ignores prometheus's plan, prometheus's host ignores nextcloud's plan, no per-host plumbing in the consumer.

**Per-bundle migration (15 bundles):**

| bundle | opt_dir | volumes | excluded_volumes |
|---|---|---|---|
| outline | yes | — | redis-data, storage-data (storage in Scaleway S3) |
| steward | yes | steward-media | steward-static (rebuildable) |
| vikunja | yes | — | — (files live under /opt/vikunja/files, covered by opt_dir) |
| bentopdf | yes | — | — (stateless; opt_dir captures compose + .env) |
| privacy-policy | yes | — | — (static site under /opt) |
| notifuse | yes | — | — (data under /opt/notifuse/data) |
| nextcloud | yes | nextcloud-data, onlyoffice-data | redis-data, nextcloud-fontcache, nextcloud-wwwcache, onlyoffice-logs, onlyoffice-cache, onlyoffice-fonts |
| decidim | yes | uploads-data | logs-data, redis-data, init-marker |
| jitsi | yes | — | — (videobridge state ephemeral; opt_dir for prosody/jicofo/jvb config) |
| espocrm | yes | espocrm-data | — |
| n8n | yes | n8n_data | — (workflows, encrypted creds, exec history) |
| prometheus | yes | prometheus-data | — (TSDB) |
| loki | yes | loki-data | — (log archive) |
| grafana | yes | grafana-data | — (user-created dashboards) |
| wazuh | yes | wazuh-indexer-data, wazuh_etc, wazuh_api_configuration, wazuh_queue, wazuh_var_multigroups, wazuh_active_response, wazuh_wodles, filebeat_etc, filebeat_var, wazuh-dashboard-custom | wazuh_logs (shipped to loki separately) |

**Pre/post hooks**: nobody ships hooks in v2.14.0. The two candidates from the v3 backlog memo (vikunja, steward "for sqlite quiescence") are both Scaleway-RDB-backed, no on-host sqlite — RDB has its own managed backups, no app-side hook needed. The hook surface is wired and ready for bundles that DO need it (e.g. a future on-host sqlite app); default conservatively empty per bundle.

**Backward compat**: old `paths`/`excludes`-only plans validate and render exactly as before. The role's union logic treats missing `opt_dir`/`volumes`/`extra_paths` as empty — a v2.13.x bundle paired with a v2.14.0 backrest is a no-op diff. A v2.14.0 bundle paired with a v2.13.x backrest passes the new fields through Terraform; the older backrest variable rejects unknown fields, so a mixed-version pairing in that direction fails to plan — bump backrest first or together. Bundles also keep the legacy `paths = ["/backup-sources/opt/<slug>"]` field populated alongside the new fields — belt + suspenders.

**Restic path dedup**: the j2 template runs `| unique` on the effective paths so the legacy `paths` entry and the opt_dir-derived path don't double-list `/backup-sources/opt/<slug>`.

---

## v2.13.2 — `application_name` knob on every authentik-integrated bundle

Adds an `application_name` input to the 13 bundles that hardcoded their Authentik portal display name: outline, steward, vikunja, bentopdf, notifuse, nextcloud, decidim, jitsi, espocrm, n8n, grafana, wazuh, backrest. Default on each matches the previous hardcoded string — zero diff for existing consumers on apply. Backrest's default is empty string, preserving the per-instance shape `Backrest (<instance_name>)` until a consumer sets a literal override.

Use case: consumers branding the portal for their org-facing identity ("Sabo Cloud Provider" instead of "Nextcloud", "Local 123 Wiki" instead of "Wiki (Outline)", etc.) without forking the bundle. Set via `apps.<bundle>.application_name` in tfvars.

Consumer-template `apps.tf` surfaces the knob as a `try(var.apps.<bundle>.application_name, "<stock>")` passthrough — same pattern as every other optional override on the bundles. Manifest entries added next to each bundle's `category_group` schema slot, `ui: advanced`.

---

## v2.13.1 — Fix dropped monitoring contributions from wazuh, backrest, diun

Peer-flagged during prod cutover audit: `consumer-template/modules/stack/apps.tf`'s `_monitoring_contribs` list was missing three bundles with non-empty `monitoring` outputs:

- **`module.wazuh.monitoring`** — wazuh's `blackbox_targets = ["https://${var.hostname}/"]` was silently dropped. Despite v2.12.0 wiring blackbox-exporter, wazuh's public UI wasn't actually being probed. **Real liveness gap closed.**
- **`module.backrest_mgmt.monitoring`** — backrest exposes `/metrics` on port 9898; its `prometheus_scrape_configs` wasn't reaching prometheus.
- **`module.diun_mgmt.monitoring`** — diun's `loki_log_paths` were being missed by loki (v2.13.0 ship gap — diun is brand new and was wired with the watchtower/autoheal precedent which also skipped aggregation; for diun the loki paths matter).

Three-line additive fix in `consumer-template/modules/stack/apps.tf`. No bundle-side changes. Existing consumers on v2.13.0 bumping to v2.13.1 immediately get wazuh blackbox alerts, backrest scrape metrics, and diun logs flowing through the monitoring stack.

Watchtower / autoheal / wazuh-agent remain absent from aggregation — they have no `monitoring.tf` to contribute.

---

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
