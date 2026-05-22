# consumer-template

The starter every new consumer of `sabokit` copies. Fill in `terraform.tfvars` + `inventory.ini`, run `terraform apply && ansible-playbook site.yml`, you have a working stack.

## What it does

`terraform/` calls `module.base` once (provisions Scaleway network, compute, Postgres, default security group, and Authentik instance config) and `module.<app>` per app you enable (provisions per-app Authentik OIDC/SAML/proxy config, DNS, S3 buckets, databases, secrets).

`ansible/` bootstraps the compute hosts (Docker, Traefik, fail2ban, log management, scw-secrets, monitoring agent) and then deploys each enabled app's stack via `import_playbook`.

The set of "enabled apps" is the single source of truth — flip `apps.outline.enabled = true` in `terraform.tfvars` and one playbook import in `site.yml`, and Outline ships end-to-end.

## Quick start

```bash
# 1. Copy this template into your own repo
cp -r consumer-template/* ~/my-org/infrastructure/
cd ~/my-org/infrastructure/

# 2. Configure
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
$EDITOR terraform/terraform.tfvars                  # fill in credentials, domains, app list

cp ansible/inventory.ini.example ansible/inventory.ini
cp ansible/group_vars/all.yml.example ansible/group_vars/all.yml

# 3. Provision infrastructure
cd terraform
terraform init
terraform apply

# 4. Wait for hosts to come up, then drop the public IPs into inventory.ini
terraform output compute_hosts
$EDITOR ../ansible/inventory.ini

# 5. Pipe per-app Terraform outputs into Ansible
terraform output -json enabled_apps > ../ansible/enabled_apps.json

# 6. Deploy
cd ../ansible
ansible-playbook site.yml -e @enabled_apps.json
```

## File layout

```
consumer-template/
├── terraform/
│   ├── versions.tf                 # required providers + backend stub
│   ├── providers.tf                # scaleway + authentik provider config
│   ├── variables.tf                # consumer inputs
│   ├── base.tf                     # module.base + module.authentik
│   ├── apps.tf                     # one module call per app
│   ├── outputs.tf                  # surfaces what ansible consumes
│   └── terraform.tfvars.example    # copy + fill in
├── ansible/
│   ├── ansible.cfg
│   ├── inventory.ini.example
│   ├── site.yml                    # bootstrap + per-app imports
│   └── group_vars/
│       └── all.yml.example
├── scripts/
│   └── bump-version.sh             # bump every ?ref=… pin to a new tag
└── README.md
```

## Adding an app

1. Find the app under `apps/<name>/` in the sabokit repo. Read its README for required inputs and what it provisions.
2. In your `terraform/apps.tf`, add a `module "<name>"` call following the Outline example. The shape is always the same: `enabled`, `hostname`, `base = local.base`.
3. In your `terraform.tfvars`, add `apps.<name> = { enabled = true, hostname = "<sub>.example.org" }`.
4. In your `ansible/site.yml`, uncomment (or add) the matching `import_playbook` line for the app.
5. `terraform apply && ansible-playbook site.yml`.

## Disabling an app

Set `apps.<name>.enabled = false` in tfvars and `terraform apply`. Terraform tears down the Authentik resources, DNS records, S3 buckets, databases, and secrets. The Docker stack on the host is **not** auto-removed — `ssh <host> && cd /opt/<app> && docker compose down -v && sudo rm -rf /opt/<app>`.

## Bumping sabokit

```bash
./scripts/bump-version.sh v1.1.0
cd terraform && terraform init -upgrade && terraform plan
```

The script rewrites every `?ref=` pin in `terraform/` to the new tag. Check the plan, then `apply`. See [sabokit CHANGELOG](https://github.com/sheyaln/sabokit/releases) for what changed between tags — major bumps may require `terraform state mv`.

## Secrets hygiene

- `terraform.tfvars`, `inventory.ini`, `group_vars/all.yml` should all be gitignored if they contain secrets. The `.example` siblings are tracked.
- Prefer `TF_VAR_*` environment variables for CI; tfvars files for local apply.
- Ansible loads Outline's app secrets from Scaleway Secret Manager at deploy time via `lookup('scaleway.scaleway.scaleway_secret', ...)`. The Scaleway credentials it uses come from `SCW_SECRETS_ACCESS_KEY` / `SCW_SECRETS_SECRET_KEY` env vars (set in your shell before `ansible-playbook`).

## Required Ansible collections

```bash
ansible-galaxy collection install community.docker community.general scaleway.scaleway
```

## Notes

- This template uses `git::https://github.com/sheyaln/sabokit.git//...?ref=v1.0.0` everywhere. Replace `sheyaln/sabokit` with your fork if you maintain one.
- The `apps/outline/` reference bundle is the worked example. Once 2-3 more apps ship (Nextcloud, Vikunja), this template will gain commented-out call sites for them. For now, add them yourself by copying the Outline pattern.
