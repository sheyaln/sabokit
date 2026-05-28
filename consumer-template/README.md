# consumer-template

The starter you copy into your own infrastructure repo. Two layers:

- **`modules/stack/`** — shared TF wiring. Every environment calls this module. When `sabokit` ships a new app bundle, you add one `module` block here once and every env picks it up.
- **`environments/<env>/`** — one dir per environment (prod, staging, …). The per-env root that `terraform` / `sabokit` deploy; non-secret per-env values live keyed in `environments/env-values.yml`.

## Layout

```
consumer-template/
├── modules/stack/                # Shared module wiring (one source of truth)
│   ├── base.tf                   # module "base"     — Scaleway primitives
│   ├── identity.tf               # module "identity" — Authentik instance
│   ├── apps.tf                   # module "<app>" per shipped app
│   ├── variables.tf, outputs.tf, versions.tf
│   └── README.md
├── environments/
│   ├── env-values.yml.example    # per-env NON-secret values, keyed by env — copy to env-values.yml
│   ├── _template/                # Copy this to create new envs (dir name = env name)
│   │   ├── main.tf               # module "stack" { source = "../../modules/stack" ... }
│   │   ├── env.tf                # resolves ../env-values.yml[<dir name>] -> local.env
│   │   ├── config.tf.example     # persistent infra SHAPE (locals.config) — copy to config.tf
│   │   ├── providers.tf          # Scaleway + Authentik providers + S3 backend
│   │   ├── variables.tf          # secrets only (SCW creds, authentik token)
│   │   ├── secrets.tf            # optional scaleway_secret_version data sources
│   │   ├── backend.hcl.example
│   │   ├── inventory.ini.example
│   │   ├── .gitignore
│   │   └── README.md             # per-env runbook (manual + CLI)
│   └── (your envs land here)
├── apps-manifest.yaml            # GUI-consumable declaration of every app bundle
├── scripts/
│   ├── bump-version.sh           # Bump every ?ref=… pin to a new tag
│   └── import-base-image.sh      # Pull the pre-baked Scaleway image into your project
├── .gitignore
└── README.md
```

## Quick start

The supported path is [sabokit-cli](https://github.com/sheyaln/sabokit-cli). It wraps every terraform / ansible / scaleway-cli invocation in pinned docker images — the only host requirements are `docker` and `ssh`. No local terraform, ansible, jq, python, scw.

```bash
curl -fsSL https://raw.githubusercontent.com/sheyaln/sabokit-cli/master/install.sh | bash

export SCW_ACCESS_KEY=... SCW_SECRET_KEY=... SCW_DEFAULT_PROJECT_ID=...

# 1. Scaffold the project (clones this template at a pinned tag, prompts for
#    base_domain / org / first env / ssh user+key, writes .sabokit/config.yml
#    and environments/env-values.yml)
sabokit init my-stack
cd my-stack

# 2. Optionally tweak per-env values, or the shape, before first deploy
$EDITOR environments/env-values.yml      # project_id / domains / sizes (per env)
$EDITOR environments/prod/config.tf      # compute_hosts / identity / apps (shape)

# 3. Full first deploy: terraform apply (base + identity), ansible bootstrap,
#    terraform apply (full), every enabled app's ansible playbook, end-to-end.
sabokit up

# 4. Subsequent app redeploys / config pushes
sabokit deploy                    # all enabled apps
sabokit deploy --apps wazuh       # one app (its playbook + tags)
sabokit deploy --apps backrest    # re-render config + restart on every host
sabokit status                    # tf outputs + docker ps across hosts
sabokit secrets list --tag authentik
```

`sabokit init` does the equivalent of `cp -r consumer-template/` + `cp -r environments/_template environments/prod` + `cp *.example` + scaffolding state buckets. **The CLI is an assistant, not a requirement:** `env.tf` reads `env-values.yml` itself, so plain `terraform apply` works in any env dir with no CLI. `sabokit up` just orchestrates the two terraform phases + ansible + admin-token fetch.

For staging or any other env, `sabokit init --env staging` repeats the scaffold under `environments/staging/` (and adds a `staging:` key to `env-values.yml`). Each env has its own state, its own credentials, its own deploy.

See `environments/_template/README.md` for the per-env runbook — the same deploy by hand (plain terraform + ansible) and via the CLI.

## Adding an app

```bash
sabokit apps list                 # browse the catalog (NAME, CATEGORY, DESCRIPTION)
sabokit apps add wazuh            # edits environments/<env>/config.tf — uncomments the module, flips enabled
$EDITOR environments/prod/config.tf  # set hostname + any per-app overrides
sabokit up                        # picks up the new app on next apply + deploys
```

The manual path: add a `module "<name>"` block to `modules/stack/apps.tf` (following the Outline pattern), set `apps.<name> = { enabled = true, hostname = "…" }` in `config.tf`, then `terraform -chdir=environments/<env> apply` + `ansible-playbook "$SABOKIT_DIR/platform/ansible/site.yml" -i inventory.ini -e @.ansible-vars.json --tags <name>`. The umbrella playbook is `site.yml` (which imports `bootstrap.yml` + `host-services.yml` + `core.yml` + `apps.yml`); use `--tags <name>` to scope to one app, `--tags core` for monitoring stack only, `--tags apps` to skip bootstrap + host-services + core.

## Bumping sabokit

```bash
./scripts/bump-version.sh v2.1.0
for env in environments/*/; do
  [[ -d "$env" && "$env" != */"_template"/ ]] || continue
  (cd "$env" && terraform init -upgrade && terraform plan)
done
```

Major bumps may require `terraform state mv` — check the release notes.

## Secrets hygiene

`environments/env-values.yml` is committed — it holds only NON-secret per-env values. `backend.hcl`, `inventory.ini`, `.json` runtime artifacts, and `.envrc` (secrets) are gitignored; `.example` siblings are tracked. Credentials come from `SCW_*` / `TF_VAR_*` env vars (or a gitignored `.envrc`), never a committed file.

## Required tools

```bash
brew install terraform ansible jq scaleway-cli   # or apt/dnf equivalents
ansible-galaxy collection install community.docker community.general scaleway.scaleway
```
