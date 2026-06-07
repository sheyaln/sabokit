# Contributing

Operator-facing project. Standing rules live in `CLAUDE.md`; this file
captures conventions that show up in code review.

## Commits

- Plain-English one-liner subjects, verb-first. No conventional-commits prefix.
- No attribution trailers.

## Branches

- Default branch is `master`. Never `main`. Applies to scripts, CI, docs, and PR base.

## Comments

- Only explain the unclear "why", never the "what".
- Terse, non-marketing tone.

## Conventions

### Service accounts in Terraform

Every `authentik_user { type = "service_account" }` resource MUST set
`is_active = true` explicitly. Default-off would require a manual UI flip
to make the bundle's API token usable on first apply.

Live examples: `platform/application/n8n/terraform/authentik.tf`,
`platform/application/steward/terraform/authentik.tf`.

Audit when adding a new bundle that ships its own service account: confirm
`is_active = true` is present and the inline comment explains why.

### Consumer template config

Per-env config lives in committed YAML under
`consumer-template/environments/<env>/`: `common.yml` (cross-env, one level up),
`env.yml`/`hosts.yml` (per-env), and one
`{infra,identity,operations,application}.yml` per layer. Each layer's `stack.tf`
reads them. Credentials never go in those files — only in env vars
(`SCW_ACCESS_KEY`, `SCW_SECRET_KEY`); the Authentik admin token is fetched from
the infra bootstrap secret by the deploy scripts.
