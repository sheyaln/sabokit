# bentopdf

BentoPDF — browser-based PDF toolkit (merge, split, OCR, redact). Stateless: no DB, no secrets, no S3. Authentik proxy-provider + per-app group, DNS record, single-container docker-compose deploy behind Traefik.

BentoPDF doesn't speak OIDC. It's protected via Authentik's embedded outpost using the `authentik-auth@docker` Traefik middleware. The consumer **must** pass `module.bentopdf.authentik_provider_id` into the identity module's `extra_forward_auth_provider_ids`, otherwise the outpost ignores the route and Traefik returns 500.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enabled` | `bool` | `false` | Master toggle. |
| `base` | `any` | — | Outputs from `module.base`. |
| `hostname` | `string` | `""` | Full hostname (required when enabled). |
| `category_group` | `string` | `"Tools"` | Authentik portal category. |
| `icon_url` | `string` | `null` | Icon path in Authentik media. |
| `authorized_groups` | `list(string)` | `["member"]` | Authentik group names allowed in. Higher tiers nest under lower, so a baseline tier admits everyone above. |
| `monitoring_enabled` | `bool` | `true` | Contribute to the monitoring aggregate. |
| `deployment_host_key` | `string` | `"apps"` | Key in `base.compute.hosts` for the target VM. |
| `image` | `string` | `"ghcr.io/alam00000/bentopdf:latest"` | Full image reference (repo + tag). Default = official BentoPDF image. |

## Outputs

| Name | Description |
|------|-------------|
| `enabled` | Mirrors `var.enabled`. |
| `app_url` | `https://<hostname>` or `null`. |
| `authentik_provider_id` | Proxy-provider ID — feed into identity's `extra_forward_auth_provider_ids`. |
| `authentik_application_group_id` | Per-app group `app-bentopdf`. |
| `monitoring` | Monitoring contribution (log paths only — no metrics). |
| `ansible` | `{role_path, playbook, host_group, vars}`. |
