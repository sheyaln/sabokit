# backlog

## v3.2.x

- universal `extra_env_vars` knob across every app bundle - outline opt-out
- automatic n8n workflow import on deploy
- promote `bootstrap-protonmail-bridge` branch when SMTP gap surfaces
- decide `bootstrap/` namespace shape - per-provider vs abstract gateway
- enforce uniqueness on `member_id` custom user attribute via prompt-stage policy
- port `member_id` field to enrollment flow
- `credentials_preserve` external-source mode - reads from consumer map, no bag pre-populate
- manual-enrollment re-enrollment collision - static "account exists" message + email-uniqueness policy
- generic "extra docker networks" pattern across all bundles
- drop notifuse bundle

## security & hardening

- sshd hardening - key-only auth, disable root login, port move, fail2ban integration, baseline config rendered by a base-layer role
- trivy in CI - scan published runner image + per-bundle container images for CVEs at tag time
- trufflehog in CI - secret-scan the tree on PR + pre-tag

## v3.x architectural

- scw-inject as canonical secret injection
- pick per-host secret blast-radius posture - per-host scaleway projects vs status-quo file-perm hygiene
- compose files committable static + compose v2 profiles
- authentik TF → blueprints migration

## backrest content-intelligence

- grow `backup_plan` with `opt_dir` / `volumes` / `excluded_volumes` / `extra_paths` / `pre_hooks` / `post_hooks`
- per-bundle author specifies shape - ~30-40 min each

## v4.0.0

- portainer CE as optional read-write GUI over running stacks
- remove `bucket_name_override` knob
- remove `credentials_preserve` knob

## bundle / integration follow-ups

- postiz S3 storage support - when `gitroomhq/postiz-app#1124` merges
- backrest per-instance slug collision fix - if collision surfaces
- SCIM bridge: authentik → app provisioning (outline / espocrm / nextcloud / vikunja / decidim)
- verify status of upstream notifuse OIDC SSO contribution
- `outline-authentik-group-sync` bundle - blocked on outline shipping a service-account-token CLI or admin-bootstrap env-var (no zero-touch token mint today)
- generic `jsm_severity_gate` knob on grafana bundle

## sibling-project integration

- steward phase 5 - ansible role + integration PR
- sabokit manager - depends on shipped `apps-manifest.yaml`
