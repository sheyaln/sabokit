# backlog

## v3.x architectural (foundational)

- scw-inject as canonical secret injection
- pick per-host secret blast-radius posture - per-host scaleway projects vs status-quo file-perm hygiene
- compose files committable static + compose v2 profiles
- authentik TF → blueprints migration

## v4.0.0

- portainer CE as optional read-write GUI over running stacks
- remove `bucket_name_override` knob
- remove `credentials_preserve` knob

## bundle / integration follow-ups

- postiz S3 storage support - when `gitroomhq/postiz-app#1124` merges
- backrest per-instance slug collision fix - if collision surfaces
- SCIM bridge: authentik → app provisioning (outline / espocrm / nextcloud / vikunja / decidim)
- verify status of upstream notifuse OIDC SSO contribution
- `outline-authentik-group-sync` bundle - blocked on outline shipping a service-account-token CLI or admin-bootstrap env-var

## sibling-project integration

- steward phase 5 - ansible role + integration PR
- sabokit manager - depends on shipped `apps-manifest.yaml`
