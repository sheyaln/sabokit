# Sabokit

A Terraform + Ansible blueprint for self-hosting an identity-managed application suite on Scaleway. You consume tagged versions of its modules from your own infrastructure repository — clone [`consumer-template/`](./consumer-template/), fill in per-env config, run three commands.

The blueprint covers the two layers that are tedious to get right: provider-side primitives (network, compute, storage, secrets, DNS) and an opinionated Authentik configuration (flows, sources, groups, per-app providers). One pre-baked Scaleway image per release cuts host-bootstrap time from ~10 minutes to under one.

---

## Quick start

```bash
# 1. Copy the template into your own repo.
cp -r sabokit/consumer-template my-infra
cd my-infra/environments/_template     && mv ../_template ../staging
cd staging
cp terraform.tfvars.example terraform.tfvars      && $EDITOR terraform.tfvars
cp backend.hcl.example      backend.hcl           && $EDITOR backend.hcl
cp inventory.ini.example    inventory.ini

# 2. Deploy.
./preflight.sh         # one-time per env: CLI deps, SSH key, DNS zone check
./up.sh                # provision infra + install Authentik (~10 min cold-start)
./configure.sh         # configure Authentik (flows, brand, groups) + app TF
# Then deploy apps:
ansible-playbook ../../sabokit/platform/ansible/apps.yml \
  -i inventory.ini -e @.ansible-vars.json \
  -e env_name=staging -e gateway_domain=$(awk -F= '/^[[:space:]]*gateway_domain/{gsub(/[ "#]/,"",$2); print $2; exit}' terraform.tfvars)
```

Each step has a verifiable checkpoint. See [`consumer-template/environments/_template/README.md`](./consumer-template/environments/_template/README.md) for details.

### Faster cold-starts with a pre-baked image

Optional but recommended: import the sabokit base image once per Scaleway project and `up.sh` skips ~7 minutes of apt installs:

```bash
./consumer-template/scripts/import-base-image.sh v2.1.0
# → prints IMAGE_ID; paste into terraform.tfvars under compute_hosts.<name>.image
```

See [`packer/README.md`](./packer/README.md) for the maintainer-side build flow.

---

## Repository layout

```
modules/                                # Low-level Terraform primitives. No application semantics.
├── infrastructure/{app_dns, common_security_rules, compute, network,
│                    secrets, security_group, storage/{object_bucket,
│                    postgres, postgres_database}}
└── authentik/{oidc-app, saml-app, bookmark, traefik-forward-auth}

platform/                               # The platform every consumer needs.
├── base/                               # Always-on Scaleway primitives.
│   ├── terraform/                      #   Network, compute, postgres, default SG,
│   │                                   #   gateway DNS record.
│   └── ansible/roles/                  #   Bootstrap roles: docker, traefik, fail2ban,
│                                       #   scw-secrets, monitoring-agent, ufw,
│                                       #   log-mgmt, unattended-upgrades.
│                                       #   Every role no-ops on a fc-base image.
├── identity/                           # Authentik instance.
│   ├── bootstrap/                      #   Pre-Authentik TF: admin secret + DB + token.
│   ├── terraform/                      #   Post-Authentik TF: flows, brand, groups,
│   │                                   #   outpost (configured via API).
│   └── ansible/roles/authentik-server/ #   Installs the Authentik docker stack.
├── apps/                               # One self-contained bundle per app.
│   ├── outline/{terraform, ansible/roles/outline, monitoring}
│   └── steward/{terraform, ansible/roles/steward}
└── ansible/                            # Orchestration only — no role definitions here.
    ├── ansible.cfg                     #   roles_path points at every bundle's ansible/roles.
    ├── bootstrap.yml                   #   docker, traefik, ..., authentik-server.
    ├── apps.yml                        #   Per-enabled-app import_playbook.
    └── site.yml                        #   bootstrap + apps.

consumer-template/                      # The starter you cp into your own repo.
├── modules/stack/                      #   Shared TF wiring; one source of truth across envs.
├── environments/_template/             #   Copy to prod/, staging/, etc.
│   ├── main.tf, providers.tf, variables.tf
│   ├── terraform.tfvars.example, backend.hcl.example, inventory.ini.example
│   ├── preflight.sh                    #   Idempotent env-readiness check.
│   ├── up.sh                           #   Step 1: provision + install platform.
│   ├── configure.sh                    #   Step 2: configure Authentik + app TF.
│   └── _lib.sh                         #   Shared helpers (sourced by both scripts).
└── scripts/{bump-version.sh, import-base-image.sh}

packer/                                 # Pre-baked Scaleway base image (Ubuntu + docker +
└── base.pkr.hcl + provisioners/        # ufw + fail2ban + node_exporter + cadvisor + scw CLI).

tests/local-validate/                # In-repo terraform-validate harness for CI.
```

---

## Consuming a module

Every module is consumed by Git ref, pinned to a tag. **Never** consume `master`; tagged versions are the contract.

```hcl
module "private_network" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/network?ref=v2.1.0"

  name   = "prod-internal"
  region = "fr-par"
}
```

Most consumers won't call low-level modules directly — they'll call `module.stack` from `consumer-template/modules/stack/` which composes `module.base` + `module.identity_bootstrap` + `module.identity` + `module.<app>` per enabled app.

### Bumping a version

`consumer-template/scripts/bump-version.sh v2.1.0` rewrites every `?ref=` pin under `modules/stack/` AND moves the `sabokit` git submodule to the same tag in one pass. Leaves the working tree dirty — you commit.

---

## What this repo provides, what you provide

| Blueprint provides                                          | You provide                                       |
|-------------------------------------------------------------|---------------------------------------------------|
| Scaleway network, compute, postgres, storage, DNS, secrets  | Scaleway project + IAM credentials                |
| Authentik instance (flows, brand, social sources, outpost)  | Operations contact email + your group taxonomy    |
| Per-app OIDC/SAML providers + S3 buckets + per-app DBs      | Your hostnames (`wiki.example.org`, etc.)         |
| Ansible roles to deploy each app via docker-compose         | Your inventory (host group memberships)           |
| `consumer-template/` with the 3-step deploy flow            | Your domains, registered + delegated to Scaleway  |
| Optional pre-baked Scaleway image (~3 min bootstrap)        | Optional: cross-project DNS credentials           |

Substrate assumption: Docker Compose on Scaleway VMs. K8s consumers would fork the `ansible/` side of each app bundle and replace it with manifests.

### Cross-project DNS

When your DNS zone lives in a Scaleway project separate from your infra (common for orgs that centralize domains), override the `scaleway.dns` aliased provider in your `providers.tf` with separate credentials. See `consumer-template/environments/_template/providers.tf` for the pattern.

---

## Versioning

Tagged releases follow [semver](https://semver.org/):

- **Patch** (`v1.0.1`) — bug fixes, doc-only changes. Always safe.
- **Minor** (`v1.1.0`) — additive: new variables (with defaults), new outputs, new app bundles. Safe.
- **Major** (`v2.0.0`) — breaking: variable renames, removed outputs, resource address changes requiring `terraform state mv`. Migration notes ship with the release.

Find tags at [github.com/sheyaln/sabokit/tags](https://github.com/sheyaln/sabokit/tags). Pre-1.0 tags (`infra-modules-v0.4.0`) exist for the legacy library shape and are not compatible with the v1.x platform layout.

---

## Module conventions

Every module follows the contract in [CONVENTIONS.md](./CONVENTIONS.md). The platform↔app contract lives in [ARCHITECTURE.md](./ARCHITECTURE.md). Highlights:

- Required inputs have no default. Optional inputs default to a generic value or `null` (meaning "create one for me").
- Modules never assemble subdomains. You pass full hostnames as inputs.
- Every app bundle is `enabled`-gated. `enabled = false` provisions zero resources.
- No org-specific defaults. No hardcoded group names. No hardcoded URLs.

Per-module documentation lives next to each module's `main.tf`.

---

## Project status

The 3-step consumer flow (`preflight.sh` / `up.sh` / `configure.sh`) is dogfooded against a real staging Scaleway project every release cycle. The platform↔app contract is validated in CI by `tests/local-validate/`. Shipping app bundles: Outline (wiki) and Steward (Authentik admin UI). More land per minor release; the pattern is the same every time — start from `platform/apps/outline/` as the reference.

## License

[MIT](./LICENSE).
