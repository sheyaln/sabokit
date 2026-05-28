# consumer-template

The starter you copy into your own infrastructure repo. Two layers:

- **`modules/stack/`** — shared TF wiring. Every environment calls this module. When `sabokit` ships a new app bundle, you add one `module` block here once and every env picks it up.
- **`environments/<env>/`** — one dir per environment (prod, staging, …). Per-env tfvars, remote-state backend config, Ansible inventory, and the 3 scripts (`preflight.sh` / `up.sh` / `configure.sh`) that drive a deploy.

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
│   ├── _template/                # Copy this to create new envs
│   │   ├── main.tf               # module "stack" { source = "../../modules/stack" ... }
│   │   ├── providers.tf          # Scaleway + Authentik provider config + S3 backend
│   │   ├── variables.tf
│   │   ├── terraform.tfvars.example
│   │   ├── backend.hcl.example
│   │   ├── inventory.ini.example
│   │   ├── preflight.sh          # Step 0: env readiness check
│   │   ├── up.sh                 # Step 1: provision + bootstrap + install Authentik
│   │   ├── configure.sh          # Step 2: configure Authentik + per-app TF
│   │   ├── _lib.sh               # Shared helpers
│   │   ├── .gitignore
│   │   └── README.md             # Per-env runbook
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
#    base_domain / org / first env / ssh user+key, writes .sabokit/config.yml)
sabokit init my-stack
cd my-stack

# 2. Optionally tweak compute_hosts / identity / apps before first deploy
$EDITOR environments/prod/config.tf

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

`sabokit init` does the equivalent of `cp -r consumer-template/` + `cp -r environments/_template environments/prod` + `cp *.example` + scaffolding state buckets. The shell scripts (`preflight.sh` / `up.sh` / `configure.sh`) and the per-env `_template/` layout described below still exist as a fallback for operators who want raw terraform / ansible without docker — `sabokit up` shells through to the same playbooks and state files.

For staging or any other env, `sabokit init --env staging` repeats the scaffold under `environments/staging/`. Each env has its own state, its own credentials, its own deploy.

See `environments/_template/README.md` for per-step checkpoints if you're driving terraform / ansible manually.

## Adding an app

```bash
sabokit apps list                 # browse the catalog (NAME, CATEGORY, DESCRIPTION)
sabokit apps add wazuh            # edits environments/<env>/config.tf — uncomments the module, flips enabled
$EDITOR environments/prod/config.tf  # set hostname + any per-app overrides
sabokit up                        # picks up the new app on next apply + deploys
```

The manual path is still supported: add a `module "<name>"` block to `modules/stack/apps.tf` (following the Outline pattern), set `apps.<name> = { enabled = true, hostname = "…" }` in `config.tf`, then `./configure.sh` + `ansible-playbook ../../sabokit/platform/ansible/site.yml -i inventory.ini -e @.ansible-vars.json --tags <name>`. The umbrella playbook is `site.yml` (which imports `bootstrap.yml` + `host-services.yml` + `core.yml` + `apps.yml`); use `--tags <name>` to scope to one app, `--tags core` for monitoring stack only, `--tags apps` to skip bootstrap + host-services + core.

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

`terraform.tfvars`, `backend.hcl`, `inventory.ini`, and any `.json` runtime artifact are gitignored. `.example` siblings are tracked. Prefer `TF_VAR_*` env vars in CI; tfvars files for local apply.

## Required tools

```bash
brew install terraform ansible jq scaleway-cli   # or apt/dnf equivalents
ansible-galaxy collection install community.docker community.general scaleway.scaleway
```
