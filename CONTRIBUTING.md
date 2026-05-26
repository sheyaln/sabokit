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

Live examples: `platform/apps/n8n/terraform/authentik.tf`,
`platform/apps/steward/terraform/authentik.tf`.

Audit when adding a new bundle that ships its own service account: confirm
`is_active = true` is present and the inline comment explains why.

### Consumer template config

Per-env config lives in `consumer-template/environments/<env>/config.tf` as
a `locals { config = {...} }` block. Committable. Credentials never go in
that file — only in env vars (`SCW_ACCESS_KEY`, `SCW_SECRET_KEY`,
`TF_VAR_*`) or via `data "scaleway_secret_version"` references in
`secrets.tf` (bag UUIDs committable, payloads stay in Scaleway).

See `consumer-template/environments/MIGRATION-v3.1.10-config-tf.md` for the
shape and the legacy-`terraform.tfvars` migration path.
