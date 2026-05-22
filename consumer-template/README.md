# consumer-template

The starter you copy into your own infrastructure repo. Two layers:

- **`modules/stack/`** — shared TF wiring. Every environment calls this module. When `sabokit` ships a new app bundle, you add one `module` block here once and every env picks it up.
- **`environments/<env>/`** — one dir per environment (prod, staging, …). Per-env tfvars, remote-state backend config, Ansible inventory, and a `deploy.sh` that runs `terraform apply && ansible-playbook` in order.

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
│   │   ├── deploy.sh             # TF first, Ansible second
│   │   ├── .gitignore
│   │   └── README.md
│   └── (your envs land here)
├── scripts/
│   └── bump-version.sh           # Bump every ?ref=… pin to a new tag
├── .gitignore
└── README.md
```

## Quick start

```bash
# 1. cp the template into your infra repo (alongside sabokit as a submodule)
git clone https://github.com/sheyaln/sabokit.git
cp -r sabokit/consumer-template/* my-infra/

# 2. Create your first environment
cd my-infra
cp -r environments/_template environments/prod
cd environments/prod

# 3. Configure
cp terraform.tfvars.example terraform.tfvars       $EDITOR terraform.tfvars
cp backend.hcl.example      backend.hcl            $EDITOR backend.hcl
cp inventory.ini.example    inventory.ini          # update later with real IPs

# 4. Provision + deploy
./deploy.sh

# 5. After first apply, drop the host IPs into inventory.ini, re-run
terraform output compute_hosts
$EDITOR inventory.ini
./deploy.sh --skip-tags bootstrap
```

For a second env (staging), `cp -r environments/_template environments/staging` and repeat. Each env has its own state, its own credentials, and its own deploy.

## Deploy cadence

- **First apply on a fresh env**: `./deploy.sh` — terraform apply, then full Ansible bootstrap + apps.
- **Routine app redeploy**: `./deploy.sh --skip-tags bootstrap` — seconds.
- **One app at a time**: `./deploy.sh --tags outline`.
- **Terraform-only**: `terraform -chdir=environments/prod apply` and skip Ansible.

## Adding an app

1. Find the app under `platform/apps/<name>/` in `sabokit`. Read its README.
2. In `modules/stack/apps.tf`, add a `module "<name>"` block following the Outline pattern.
3. In each env's `terraform.tfvars`, add `apps.<name> = { enabled = true, hostname = "…" }`.
4. In `sabokit/platform/ansible/apps.yml`, the `import_playbook` for that app is already there if the bundle ships — `deploy.sh` will pick it up.
5. `./deploy.sh`.

## Bumping sabokit

```bash
./scripts/bump-version.sh v1.1.0
for env in environments/*/; do
  [[ -d "$env" && "$env" != */"_template"/ ]] || continue
  (cd "$env" && terraform init -upgrade && terraform plan)
done
```

Major bumps may require `terraform state mv` — check the release notes.

## Secrets hygiene

`terraform.tfvars`, `backend.hcl`, `inventory.ini`, and any `.json` runtime artifact are gitignored. `.example` siblings are tracked. Prefer `TF_VAR_*` env vars for CI; tfvars files for local apply.

## Required tools

```bash
brew install terraform ansible jq        # or apt/dnf equivalents
ansible-galaxy collection install community.docker community.general scaleway.scaleway
```
