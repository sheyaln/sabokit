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

## Ops payload (watchtower + autoheal + backrest)

The template ships three platform host-services that together form the prod-default ops payload: **Watchtower** (auto-update opted-in containers), **Autoheal** (restart unhealthy containers), and **Backrest** (restic-based backups). They're plug-and-play — no per-app wiring needed.

```hcl
# In terraform.tfvars
apps = {
  watchtower_apps = { enabled = true }                              # one per host
  autoheal_apps   = { enabled = true }
  backrest_mgmt   = { enabled = true, hostname = "backup.example.org", instance_name = "mgmt" }
  # ... your apps
}
```

Per-app behaviour is controlled by knobs on every bundle (smart defaults shipped):

- `auto_update_enabled` — render the Watchtower label. Defaults ON for stateless / safe-update apps (bentopdf, outline, vikunja, steward, notifuse, privacy-policy, backrest); OFF for breaking-change apps (nextcloud, decidim, espocrm, n8n, jitsi, authentik).
- `autoheal_enabled` — render the Autoheal label. Default ON everywhere.
- `backup_enabled` — emit a Backrest plan contribution for this app. Default ON for apps with host-side state.
- `backup_extra_paths`, `backup_schedule_cron`, `backup_retention` — per-app overrides on the auto-generated plan.

Backrest auto-aggregates every enabled app's `backup_plan` output — no need to hand-curate `backup_plans` lists unless you want extras. Each Backrest instance gets the full union; restic skips paths that don't exist on its host.

Multi-host: instantiate `watchtower_apps`, `autoheal_apps`, `backrest_mgmt` once per host (copy the module block, swap the keys).

## Bumping sabokit

```bash
./scripts/bump-version.sh v2.5.0
for env in environments/*/; do
  [[ -d "$env" && "$env" != */"_template"/ ]] || continue
  (cd "$env" && terraform init -upgrade && terraform plan)
done
```

Major bumps may require `terraform state mv` — check `CHANGELOG.md` (root of sabokit) for the breaking-changes list per release.

## Secrets hygiene

`terraform.tfvars`, `backend.hcl`, `inventory.ini`, and any `.json` runtime artifact are gitignored. `.example` siblings are tracked. Prefer `TF_VAR_*` env vars in CI; tfvars files for local apply.

## Required tools

```bash
brew install terraform ansible jq scaleway-cli   # or apt/dnf equivalents
ansible-galaxy collection install community.docker community.general scaleway.scaleway
```
