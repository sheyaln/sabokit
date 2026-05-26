# Migration: `terraform.tfvars` → `config.tf` (v3.1.10)

## Why

Pre-v3.1.10 each env dir used `terraform.tfvars` for its entire configuration.
That made the file non-committable: most consumers had to either inline real
secrets into it (SCW keys, smtp passwords, jotform API tokens) OR document
the values out-of-band so nothing in the repo accurately described the
deployed infrastructure.

`config.tf` restores git auditability:

- the whole infra spec ships in source control as an HCL `locals { config = {...} }` block
- diffs land in PR review like any other code change
- the only things still out of git are runtime credentials (`SCW_ACCESS_KEY`,
  `SCW_SECRET_KEY`) which must come from env vars, and the Authentik admin
  token which the deploy scripts fetch from a Scaleway secret at runtime
- Scaleway-stored secrets surface in `secrets.tf` via
  `data "scaleway_secret_version"` — bag UUIDs are committable, payloads stay
  in Scaleway

Plan-time `validation {}` blocks were added to every variable in
`consumer-template/modules/stack` so misconfiguration shows up as a precise
error at `terraform plan` rather than as a confusing apply-time failure or
silent runtime breakage.

## What changed in `_template/`

| Before | After | Notes |
|---|---|---|
| `terraform.tfvars` (gitignored) | `config.tf` (committable) | `locals { config = {...} }` block |
| `terraform.tfvars.example` | `config.tf.example` | annotated template |
| `variables.tf` (large) | `variables.tf` (3 vars) | only credentials + Authentik admin token |
| `main.tf` reads `var.*` | `main.tf` reads `local.config.*` | upstream-maintained; no consumer edits |
| — | `secrets.tf` | optional `data "scaleway_secret_version"` references |
| `_lib.sh` parses `terraform.tfvars` | `_lib.sh` parses `config.tf` | same awk regex, different filename |

`.gitignore` drops `terraform.tfvars` from its ignore list (the file no
longer exists). It still ignores `backend.hcl`, `inventory.ini`, state, and
plan files.

## Migration procedure (existing consumer)

Run per environment. Idempotent at every step — back out by `git checkout` if
anything looks wrong before `apply`.

### 1. Pull sabokit v3.1.10

Bump your consumer's `?ref=` pins from `v3.1.9` to `v3.1.10`. The stack
module now requires `var.identity` (it was previously a flat passthrough but
is now a required input on `module "stack"`).

### 2. Translate `terraform.tfvars` → `config.tf`

Copy the new template:

```bash
cp config.tf.example config.tf
```

Then for each `key = value` line in your existing `terraform.tfvars`, find
the matching slot in `config.tf` under `locals { config = {...} }` and paste
the value across. Direct one-to-one translation — same keys, same types,
same defaults. Examples:

```hcl
# terraform.tfvars (old)
scaleway_project_id = "abcdef..."
base_domain         = "example.org"
gateway_domain      = "auth.example.org"

apps = {
  outline = { enabled = true, hostname = "wiki.example.org" }
}
```

becomes

```hcl
# config.tf (new)
locals {
  config = {
    scaleway_project_id = "abcdef..."
    base_domain         = "example.org"
    gateway_domain      = "auth.example.org"

    apps = {
      outline = { enabled = true, hostname = "wiki.example.org" }
    }
  }
}
```

### 3. Move secrets out

Anything in the old `terraform.tfvars` that was a *secret value* (not a bag
ID): create a Scaleway secret holding it, then either

- if the secret is consumed by an app bundle by NAME (e.g. `smtp_secret_name`)
  — set the name in `local.config.smtp_secret_name` and let the bundle's
  ansible role resolve at deploy time.

- if the secret is consumed by Terraform itself (rare — typically only when
  a sibling .tf in this env needs the payload) — add a
  `data "scaleway_secret_version"` block in `secrets.tf` with the bag UUID
  (committable), and reference it where needed:

  ```hcl
  data "scaleway_secret_version" "my_api_key" {
    secret_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    revision  = "latest"
  }

  # consumed as: jsondecode(data.scaleway_secret_version.my_api_key.data).api_key
  ```

`scaleway_access_key` / `scaleway_secret_key` MUST move to env vars. Set
either `SCW_ACCESS_KEY` / `SCW_SECRET_KEY` (consumed by `_lib.sh`) or
`TF_VAR_scaleway_access_key` / `TF_VAR_scaleway_secret_key` (consumed by
Terraform directly). `_lib.sh` accepts either pair and re-exports the SCW
set so the provider sees a single credential source.

### 4. Plan — expect zero diff

```bash
./preflight.sh
terraform plan
```

The refactor preserves the module input signature byte-for-byte. A clean
migration produces `No changes. Your infrastructure matches the configuration.`

If you see drift, audit:
- key names: `local.config.xxx` must match what was in `terraform.tfvars`
- types: `compute_hosts` is a map of objects, `apps` is a map of objects, etc.
  Terraform will reject a misshapen input at plan with a precise error thanks
  to the new validation blocks.
- the `identity = {...}` block is now passed as `var.identity` (was already
  the case in v3.1.9 — no shape change).

### 5. Apply + delete the old file

Once `terraform plan` is clean:

```bash
terraform apply
git rm terraform.tfvars
git add config.tf secrets.tf .gitignore variables.tf main.tf
git commit -m "Migrated env to config.tf"
```

The new `.gitignore` still ignores `backend.hcl`, `inventory.ini`, state,
and plans — only `terraform.tfvars` was dropped from the ignore list (it
no longer exists).

## Sibling `.tf` files in the env dir

Consumers running custom resources (Cloudflare, custom IAM, KMS-managed
buckets, etc.) outside the stack module should keep those as sibling `.tf`
files in the same env directory. They have full access to `local.config.*`
since they share the same root module. Pattern:

```
environments/prod/
  config.tf         # locals.config — upstream pattern, consumer-edited
  main.tf           # module.stack call — upstream-maintained
  secrets.tf        # scaleway secret data sources — consumer-edited
  cloudflare.tf     # consumer-owned Cloudflare DNS — consumer-edited
  variables.tf      # SCW creds + Authentik token — upstream-maintained
  ...
```

This is the same pattern as before; only the *file the consumer's primary
config lives in* changed.

## Rollback

If a migrated env needs to revert to `terraform.tfvars` for any reason, the
shape is mechanical:

1. Re-add `terraform.tfvars` to `.gitignore`.
2. Restore the v3.1.9 `variables.tf` (full variable surface), `main.tf`
   (var.* references), and delete `config.tf` + `secrets.tf`.
3. Restore the old `_lib.sh` + `preflight.sh` (parsed `terraform.tfvars`).
4. Pin `?ref=v3.1.9` on every module source in `consumer-template/modules/stack`.

No state changes — module addresses are identical across the refactor.
