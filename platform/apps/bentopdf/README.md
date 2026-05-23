# apps/bentopdf

BentoPDF — browser-based PDF toolkit (merge, split, OCR, redact). Self-contained bundle:

- Authentik proxy-provider + application + per-app group (forward-auth, not OIDC — the app itself has no auth integration)
- DNS A record on the consumer's base domain
- Ansible role that deploys a single-container docker-compose stack behind Traefik

No DB, no secrets, no S3. BentoPDF is stateless; everything happens in-browser or in the container's tmpfs.

## Forward-auth wiring

BentoPDF doesn't speak OIDC. Authentik's embedded outpost intercepts every request via the Traefik middleware `authentik-auth@docker` and only forwards to the container after a successful auth check.

The bundle exports `authentik_provider_id`. The consumer **must** include it in the identity module's `extra_forward_auth_provider_ids` list so the outpost knows to protect this app:

```hcl
module "identity" {
  source = "..."

  extra_forward_auth_provider_ids = compact([
    module.bentopdf.authentik_provider_id,
    # other forward-auth providers go here too
  ])
}
```

Without this, the app deploys cleanly but the outpost ignores it and the Traefik middleware route returns 500.

## Usage

```hcl
module "bentopdf" {
  source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/bentopdf/terraform?ref=v2.2.0"
  enabled  = try(var.apps.bentopdf.enabled, false)
  hostname = try(var.apps.bentopdf.hostname, "")
  base     = module.base
}
```

In `terraform.tfvars`:

```hcl
apps = {
  bentopdf = {
    enabled  = true
    hostname = "pdf.example.org"
  }
}
```

In `site.yml`:

```yaml
- import_playbook: ../apps/bentopdf/ansible/playbook.yml
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. When false the bundle provisions zero resources. |
| `base` | object | — | Outputs from `module.base`. |
| `hostname` | `string` | — (required when enabled) | Full hostname BentoPDF is served at. |
| `category_group` | `string` | `"Tools"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Optional icon path in Authentik media. |
| `access_level` | `string` | `"member"` | Key in `base.authentik.groups` granting baseline access. |
| `extra_authorized_groups` | `map(string)` | `{}` | Additional Authentik groups allowed beyond `access_level`. |
| `monitoring_enabled` | `bool` | `true` | If true and a monitoring app is enabled, log paths wire up. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` identifying the deploy target. |
| `image` | `string` | `"ghcr.io/digital-blueprint/bento-pdf:latest"` | Full BentoPDF Docker image ref. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | Proxy-provider ID; pass to identity's `extra_forward_auth_provider_ids`. |
| `authentik_application_group_id` | Per-app group `app-bentopdf`. |
| `monitoring` | Contribution map. Log paths only — BentoPDF has no metrics. |
| `ansible` | `{role_path, playbook, host_group, vars}` consumed by site.yml. |

## Disabling

Set `apps.bentopdf.enabled = false`, then `terraform apply`. Authentik resources, DNS record, and consumer-side outpost binding all go away. The container on the host needs explicit `docker compose down` from a cleanup step.
