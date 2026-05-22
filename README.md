<p align="center">
  <img src="images/fed-commons-banner.png" alt="Federated Commons" width="640" />
</p>

# Federated Commons

A Terraform module library for self-hosting an identity-managed application suite on Scaleway. This is an **upstream blueprint** — you do not run it directly. You consume tagged versions of its modules from your own infrastructure repository.

Modules cover the two layers that are tedious to get right: provider-side primitives (network, compute, storage, secrets, DNS) and an opinionated Authentik configuration (flows, sources, groups, per-app providers). Application deployment is left to you.

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
│   ├── terraform/                      #   Network, compute, postgres, default SG.
│   └── ansible/roles/                  #   Bootstrap roles: docker, traefik, fail2ban,
│                                       #   scw-secrets, monitoring-agent, ufw, log-mgmt,
│                                       #   unattended-upgrades.
├── identity/                           # Authentik instance (always-on by default;
│   ├── terraform/                      #   pluggable if you bring your own IdP).
│   └── ansible/roles/                  #   Reserved.
├── apps/                               # One self-contained bundle per app.
│   └── outline/{terraform, ansible/roles/outline, monitoring}
└── ansible/                            # Orchestration only — no role definitions here.
    ├── ansible.cfg                     #   roles_path points at every bundle's ansible/roles.
    ├── bootstrap.yml                   #   tag: bootstrap. Runs once per fresh host.
    ├── apps.yml                        #   tag: apps. Per-enabled-app import_playbook.
    └── site.yml                        #   bootstrap + apps.

consumer-template/                      # The starter you cp into your own repo.
├── modules/stack/                      #   Shared TF wiring; one source of truth across envs.
├── environments/_template/             #   Copy to prod/, staging/, etc.
│   ├── main.tf, providers.tf, variables.tf
│   ├── terraform.tfvars.example, backend.hcl.example, inventory.ini.example
│   └── deploy.sh                       #   `terraform apply` then `ansible-playbook`.
└── scripts/bump-version.sh

examples/local-validate/                # In-repo terraform-validate harness for CI.
```

A reference consumer lives under [`consumer-template/`](./consumer-template/) — copy it, add `sabokit` as a submodule, fill in per-env config, run `deploy.sh`.

---

## Consuming a module

Every module is consumed by Git ref, pinned to a tag. **Never** consume `master`; tagged versions are the contract.

```hcl
module "private_network" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/network?ref=v1.0.0"

  name   = "prod-internal"
  region = "fr-par"
}
```

Most consumers won't call low-level modules directly — they'll call `module.stack` from `consumer-template/modules/stack/` which composes `module.base` + `module.identity` + `module.<app>` per enabled app.

The `?ref=<tag>` is mandatory. See [Versioning](#versioning) below for what each tag promises.

### Bumping a version

`consumer-template/scripts/bump-version.sh v1.1.0` rewrites every `?ref=` pin under `modules/stack/` in one pass, then runs `terraform plan` per environment.

---

## What this repo provides, what you provide

The blueprint covers **infrastructure provisioning + identity wiring + app deployment scaffolding**. You bring credentials, hostnames, and the apps' own runtime config.

| Blueprint provides                                          | You provide                                       |
|-------------------------------------------------------------|---------------------------------------------------|
| Scaleway network, compute, postgres, storage, DNS, secrets  | Scaleway project + IAM credentials                |
| Authentik instance (flows, brand, social sources, outpost)  | Authentik admin token + your group taxonomy       |
| Per-app OIDC/SAML providers + S3 buckets + per-app DBs      | Your hostnames (`wiki.example.org`, etc.)         |
| Ansible roles to deploy each app via docker-compose         | Your inventory (host IPs from `terraform output`) |
| `consumer-template/` with per-env deploy script             | Your domains, registered + delegated to Scaleway  |

Substrate assumption: Docker Compose on Scaleway VMs. K8s consumers would fork the `ansible/` side of each app bundle and replace it with manifests.

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

`v1.0` candidate. The platform/app contract is validated end-to-end via `examples/local-validate/`. The reference app bundle (Outline) is complete; the other 13 apps replicate the same pattern and are being added in subsequent minor releases. Feedback on the contract is welcome via issues before v1.0.0 tags.

## License

[MIT](./LICENSE).
