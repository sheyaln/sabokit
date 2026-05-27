# platform/bootstrap/

Bootstrap-tier bundles. Host-bound services that **apps depend on at runtime**, beyond what `platform/base/` already covers.

Sibling to `platform/base/`, `platform/identity/`, `platform/apps/`. Consumers wire bundles here via `var.bootstrap.<provider>` (not `var.apps`) — see `consumer-template/modules/stack/apps.tf` for the existing `module "protonmail_bridge"` block.

See `ARCHITECTURE.md` for the full tier rationale.

## Convention: per-provider modules, not an abstract dispatcher

Each provider gets its own bundle directory under `platform/bootstrap/`. Consumers pick **one** for any given capability (e.g. mail) by enabling exactly one provider's `enabled` flag. There is no abstract `smtp-gateway` module that dispatches to providers.

Why:
- Provider semantics differ (ProtonMail Bridge: interactive first-login + IMAP host service; Scaleway TEM: API-key relay with no runtime container; generic SMTP: credentials only). An abstract dispatcher leaks every provider's quirks into a single variable surface.
- Picking a provider is a one-shot decision at consumer-template wire-up time. Run-time switching has no use case.
- Each provider's bundle stays single-purpose and reads cleanly.

## Consumer wiring

```hcl
# terraform.tfvars (or config.yaml when using consumer-template's render path)
bootstrap = {
  protonmail_bridge = {
    enabled                = true
    imap_username          = "ops@example.org"
    bridge_login_secret_id = "11111111-2222-3333-4444-555555555555"
  }
}
```

Apps that need IMAP read the well-known `imap-config` Scaleway secret the active provider writes. Apps don't care which provider produced it.

For SMTP, apps read the well-known `smtp-config` Scaleway secret. That secret is written by `platform/base/` (Scaleway TEM, always-on) unless a future bootstrap-tier SMTP provider overrides it.

## Existing providers

| Bundle | Capability | Status | Notes |
|--------|------------|--------|-------|
| `protonmail-bridge` | IMAP inbound | shipping | Runs the community ProtonMail Bridge container, bound to an apps-shared docker network. Requires interactive first-login (see bundle README). |

## Planned providers

These are not implemented yet. Listed here to lock in the per-provider convention and the variable surface shape so consumers know what to expect.

| Bundle | Capability | Notes |
|--------|------------|-------|
| `scaleway-tem-relay` | SMTP outbound (TEM-backed) | `platform/base/` already provisions `scaleway_tem_domain` + writes `smtp-config` when `tem_enabled = true`. A relay bundle would only be needed if a consumer wants an in-cluster SMTP-relay container in front of the TEM API; the API-direct path covers nearly every app already. May land as a thin opt-in container, may be elided entirely. |
| `generic-smtp-relay` | SMTP outbound (BYO credentials) | For consumers using their own SMTP provider (Mailgun, SES, self-hosted Postfix). Writes the `smtp-config` secret from a Scaleway secret holding `{host, port, username, password}`. Mutually exclusive with the TEM path. |

## Adding a new provider

1. Create `platform/bootstrap/<provider>/` mirroring `protonmail-bridge/` layout (`terraform/`, `ansible/roles/<provider>/`, `README.md`).
2. Add the bundle to `scripts/gen_apps_yml.py` `BOOTSTRAP_BUNDLES`.
3. Add a `module "<provider>"` block in `consumer-template/modules/stack/apps.tf` gated on `var.bootstrap.<provider>.enabled`.
4. Add the provider key to `var.bootstrap`'s object type in `consumer-template/modules/stack/variables.tf`.
5. Add a `<provider>` entry to `consumer-template/modules/stack/outputs.tf` `enabled_apps`.
6. Add a `bootstrap:` entry to `consumer-template/apps-manifest.yaml`.

`scripts/gen_apps_yml.py` regenerates `platform/ansible/apps.yml` so bootstrap-tier import blocks land first in the import order — apps that depend on them deploy after.
