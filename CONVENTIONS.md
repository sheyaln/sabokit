# Module Conventions

The rules every module and app bundle in this repo follows. Read [ARCHITECTURE.md](./ARCHITECTURE.md) first — that's the contract. This file is the style guide.

If you are adding a new wrapper under `platform/_shared/`, a new app bundle under `platform/application/`, or extending a layer (`platform/infra|identity|operations/`), follow these conventions. If you find a violation in existing code, fix it.

---

## Variables

### Naming
- `lowercase_snake_case`. Always.
- Group related inputs under a shared prefix: `postgres_volume_size_in_gb`, `postgres_max_connections`, not `db_size`/`max_conn`.
- The primary "thing this module is about" gets unprefixed names: `name`, `region`, `tags`. Secondary things get prefixed: `postgres_*`, `compute_*`.

### Required vs optional
- **Required** = no default. Variables that *must* be provided for the module to be meaningful (a name, an ID, a hostname).
- **Optional** = always defaulted. To a sensible value, or to `null` meaning "module decides".
- The `null` default is reserved for the "create-one / use-this-existing" pattern: `vpc_id = null` means "create one for me"; non-null means "use this existing one". Document this in the description.

### Descriptions
- Every variable has a `description`. No exceptions. The description IS the API doc.
- One sentence, sentence-cased, ending with a period. Add a second sentence only when there's a non-obvious constraint or behaviour.
- Don't restate the variable name. `description = "Name"` is useless. Say what it's the name *of* and what it's *used for*.
- When defaults matter, mention them: `"Hours between automated backups. Default 24 is sensible for most apps; bump to 6 for higher-churn workloads."`

### Validation
- Add `validation` blocks where the cost of a bad value would be a confusing downstream error.
- Validation messages are full sentences. Tell the caller what they passed and what's expected.
- Don't validate against a hardcoded enum that reflects one consumer's taxonomy. Group names like `{admin, treasurer, member}` look universal but bake one org's structure into the module, forcing every other consumer to fork. Use `type = string` and let the consumer pass any name their Authentik instance has.

### Sensitive
- Mark `sensitive = true` on anything secret-bearing. Passwords, tokens, private keys, OAuth client secrets.
- Prefer secrets-bag-via-Scaleway-secret-id over passing the value through Terraform state. State files leak; Scaleway secrets have IAM gates.

### Types
- Always declare `type`. Never let Terraform infer.
- For map/object inputs that change shape over time, use `type = object({ ... })` with `optional(...)` and defaults, NOT `type = any`. `any` lets bugs through.
- Exception: the `var.base` input on app bundles is `type = any` because Terraform can't forward-reference a module's output type at the boundary. Document the shape in the README.

---

## Resources

### Naming
- The primary resource is named `this`: `scaleway_object_bucket.this`, `authentik_application.this`.
- Secondary resources get descriptive names: `scaleway_object_bucket.attachments`, `authentik_property_mapping_provider_scope.email`.
- No abbreviations. `scaleway_rdb_user.this`, not `scaleway_rdb_user.u`.

### Counting and iteration
- `count = var.enabled ? 1 : 0` is the disable pattern for app-bundle resources. See [ARCHITECTURE.md "The enable/disable mechanism"](./ARCHITECTURE.md#the-enabledisable-mechanism).
- `for_each = toset([...])` for lists where the keys are stable.
- Do NOT use `for_each = var.enabled ? toset(["x"]) : toset([])` to gate at the module level — the address `module.outline["x"]` is awful for state moves.

### Lifecycle
- `prevent_destroy = true` only when destruction would be catastrophic and recovery is non-trivial (production databases, the embedded Authentik outpost).
- `ignore_changes` is for curbing transient changes and for fields managed out-of-band (e.g. signing keys that the provider rotates, image tags that CI bumps). Comment WHY when used.

---

## URLs and hostnames

**Modules and base/* never assemble subdomains.** Full hostnames come from consumer inputs as strings.

- BAD: `redirect_uris = ["https://wiki.${var.domain}/callback"]`
- GOOD: `redirect_uris = ["${var.hostname}/callback"]` where `var.hostname` is `"https://wiki.example.org"`

The reason: every consumer has their own subdomain convention (or none). Baking `wiki.` into the module means a consumer who prefers `kb.example.org` has to fork the module to override one string.

In app bundles, the `hostname` variable is REQUIRED (no default). Consumers always pass it. The app may *append* paths (`/callback`, `/api/oidc/code`) since those are determined by the app implementation, not the org's subdomain convention.

---

## Outputs

### Naming
- Match the input name when reflecting back: input `private_network_id`, output `private_network_id`.
- Prefer one structured output (`output "scaleway" { value = {...} }`) over many flat outputs for the platform-contract surface. See `platform/infra/terraform/outputs.tf` for the canonical shape.
- App bundle outputs are defined in [ARCHITECTURE.md "What every app bundle exports"](./ARCHITECTURE.md#what-every-app-bundle-exports). Don't add others without updating the contract.

### Sensitive
- Mark `sensitive = true` on outputs that include secrets. Default to "expose the Scaleway secret ID; let consumers fetch the value at use-time" rather than streaming the value through outputs.

### Null when disabled
- Optional outputs return `null` when disabled or when the resource doesn't exist. Use `try()` defensively when consuming:
  ```hcl
  outpost_providers = compact([
    module.backrest.authentik_provider_id,
    module.bentopdf.authentik_provider_id,
  ])
  ```

---

## Escape hatches

Every module should provide at least one of these so consumers can extend without forking:

1. **`extra_*` pass-through inputs** — `extra_inbound_rules`, `extra_docker_networks`, `additional_property_mapping_ids`. Lists or maps that the module unions with its own defaults.
2. **Raw resource ID outputs** — expose the underlying resource ID (`provider_id`, `bucket_name`, `instance_id`) so consumers can attach their own resources to it.
3. **`existing_*` bring-your-own inputs** — `existing_vpc_id`, `existing_postgres_instance_id`. When provided, the module skips creating one and uses the passed-in resource.

A module without any of these will get forked the first time someone needs the 0.5% that wasn't anticipated.

---

## File layout per module

```
<module-name>/
├── versions.tf       # required_providers + required_version
├── variables.tf      # all variable blocks
├── locals.tf         # only if there are derived values worth naming
├── main.tf           # primary resources (the bulk)
├── <topic>.tf        # split when main.tf > 200 lines, by topic
├── data.tf           # data sources, if any
├── outputs.tf        # all output blocks
└── README.md         # see below
```

A module is one purpose. If you find yourself wanting `if-this-thing-also` flags that change the resource graph dramatically, split into two modules.

---

## READMEs

Every bundle and wrapper directory under `platform/` has a `README.md` with this structure:

```markdown
# <module-name>

One-line purpose.

## Usage

```hcl
module "<name>" {
  source = "git::https://github.com/sheyaln/sabokit.git//<path>?ref=v2.1.0"

  required_input = "value"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `required_input` | `string` | — | What it does. |
| `optional_input` | `bool` | `true` | What it does. |

## Outputs

| Name | Description |
|------|-------------|
| `id` | What this is. |
```

No fluff. No "why we built this" essays — that's for ARCHITECTURE.md and commit messages. The README is a reference card.
- Tag releases at the repo root: `v1.0.0`, `v1.0.1`, `v1.1.0`. See [ARCHITECTURE.md "Versioning"](./ARCHITECTURE.md#versioning).

## When in doubt

1. Read [ARCHITECTURE.md](./ARCHITECTURE.md).
2. Look at how `platform/infra/terraform/` does it (canonical platform module) or `platform/application/outline/` (canonical app bundle).
3. If still in doubt, copy the closest existing pattern and ask in a PR.
