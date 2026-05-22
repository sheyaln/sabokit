# consumer-template/modules/stack

Shared wiring for every environment. `module "stack"` in each `environments/<env>/main.tf` calls into here. When a new app bundle ships in `sabokit`, you add it once to this module's `apps.tf` and every environment picks it up next plan.

This module has no opinions about credentials or backend — those belong to the per-env root.

## Files

| File | Role |
|------|------|
| [`base.tf`](./base.tf) | `module "base"` — Scaleway primitives (network, compute, postgres, ...). |
| [`identity.tf`](./identity.tf) | `module "identity"` — Authentik instance config. Builds `local.base` for apps. |
| [`apps.tf`](./apps.tf) | One `module "<app>"` call per shipped app, gated by `var.apps.<name>.enabled`. |
| [`variables.tf`](./variables.tf) | Inputs the per-env root passes through. No credentials. |
| [`outputs.tf`](./outputs.tf) | Surfaces for the consumer (compute hosts, gateway domain, enabled_apps). |
| [`versions.tf`](./versions.tf) | Required providers. |

## Versioning

Every `source = "git::…?ref=v…"` pin is on the same tag. The repo-root `scripts/bump-version.sh` (in the consumer's checkout of this template) rewrites them all at once.
