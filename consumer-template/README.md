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

```bash
# 1. cp the template into your infra repo (sabokit as a submodule)
git clone https://github.com/sheyaln/sabokit.git
cp -r sabokit/consumer-template/* my-infra/

# 2. Create your first environment
cd my-infra
cp -r environments/_template environments/prod
cd environments/prod

# 3. Configure
cp terraform.tfvars.example terraform.tfvars   && $EDITOR terraform.tfvars
cp backend.hcl.example      backend.hcl        && $EDITOR backend.hcl
cp inventory.ini.example    inventory.ini

# 4. Deploy (each step is idempotent; re-run any of them anytime)
./preflight.sh
./up.sh
./configure.sh
ansible-playbook ../../sabokit/platform/ansible/apps.yml \
  -i inventory.ini -e @.ansible-vars.json \
  -e env_name=prod -e gateway_domain=$(awk -F= '/^[[:space:]]*gateway_domain/{gsub(/[ "#]/,"",$2); print $2; exit}' terraform.tfvars)
```

For staging or any other env, copy `_template` again and repeat. Each env has its own state, its own credentials, its own deploy.

See `environments/_template/README.md` for the per-step checkpoints and re-deploy patterns.

## Adding an app

1. Find the app under `platform/apps/<name>/` in `sabokit`. Read its README.
2. In `modules/stack/apps.tf`, add a `module "<name>"` block following the Outline pattern.
3. In each env's `terraform.tfvars`, add `apps.<name> = { enabled = true, hostname = "…" }`.
4. Re-run `./configure.sh` to apply the new TF, then `ansible-playbook ... apps.yml` to deploy.

## Bumping sabokit

```bash
./scripts/bump-version.sh v2.0.0
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
