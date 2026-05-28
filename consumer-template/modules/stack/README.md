# consumer-template/modules/stack

Shared wiring for every environment. `module "stack"` in each `environments/<env>/main.tf` calls into here. When a new app bundle ships in `sabokit`, you add it once to this module's `apps.tf` and every environment picks it up next plan.

This module has no opinions about credentials or backend — those belong to the per-env root.

## Files

| File | Role |
|------|------|
| [`base.tf`](./base.tf) | `module "base"` — Scaleway primitives (network, compute, postgres, ...). |
| [`core.tf`](./core.tf) | `module "core"` — monitoring + SIEM stack (loki/prometheus/grafana/wazuh manager). |
| [`identity.tf`](./identity.tf) | `module "identity"` — Authentik instance config. Builds `local.base` for apps. |
| [`apps.tf`](./apps.tf) | One `module "<app>"` call per shipped app, gated by `var.apps.<name>.enabled`. |
| [`variables.tf`](./variables.tf) | Inputs the per-env root passes through. No credentials. |
| [`outputs.tf`](./outputs.tf) | Surfaces for the consumer (compute hosts, gateway domain, enabled_apps). |
| [`versions.tf`](./versions.tf) | Required providers. |

## State migrations are fork-local

This module ships **zero** `moved {}` blocks (no `migrations.tf` at v3.5.4+). Every state migration lives in the consumer's fork-local files — any `*.tf` under their env directory, or a sibling `migrations.tf` / `moved.tf`.

Why: upstream can't see what addresses a fork has in state. Any upstream `moved { to = X }` collides with a fork's own `moved { to = X }` from a different `from`, and terraform refuses both with "Each module instance can have moved from only one source instance." Caught four times in the v3.5.x patch series before settling on this rule.

If you're upgrading from v3.3.x / v3.4.x, write moved blocks for whatever state addresses you have. Common shapes:

```hcl
# Old single-instance backrest → for_each (only if you had the upstream default)
moved { from = module.backrest_mgmt;       to = module.backrest["management"] }

# Per-host backrest blocks your fork hand-instantiated
moved { from = module.backrest_tools;      to = module.backrest["tools"] }
moved { from = module.backrest_authentik;  to = module.backrest["identity"] }

# Apps-tier → host-services-tier relocations (v3.4.0)
moved { from = module.autoheal_apps;       to = module.base.module.autoheal["tools"] }
moved { from = module.wazuh_agent_apps;    to = module.base.module.wazuh_agent["tools"] }

# Apps-tier → core-tier relocations (v3.4.0)
moved { from = module.loki;        to = module.core.module.loki }
moved { from = module.prometheus;  to = module.core.module.prometheus }
moved { from = module.grafana;     to = module.core.module.grafana }
moved { from = module.wazuh;       to = module.core.module.wazuh }

# compute_hosts key renames (only if you renamed them to canonical)
moved { from = module.base.module.compute_host["apps"];       to = module.base.module.compute_host["tools"] }
moved { from = module.base.module.compute_host["authentik"];  to = module.base.module.compute_host["identity"] }
```

Greenfield deploys ignore this section — there's nothing to migrate from.

## Versioning

Every `source = "git::…?ref=v…"` pin is on the same tag. The repo-root `scripts/bump-version.sh` (in the consumer's checkout of this template) rewrites them all at once.
