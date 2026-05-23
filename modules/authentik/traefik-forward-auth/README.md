# traefik-forward-auth

Creates an Authentik Proxy Provider in `forward_single` mode, an Application backed by it, a per-app Authentik group, and one policy binding per entry in `authorized_groups`. The Proxy Provider pairs with Traefik's `forwardAuth` middleware to protect applications that don't have native OIDC/SAML support.

`authorized_groups` is a `map(string)` keyed by static role names (e.g. `admin`, `member`) so the underlying `for_each` plans cleanly even when the group UUIDs themselves are not yet known.

The consumer is responsible for binding the resulting `provider_id` to an Authentik outpost (typically the embedded outpost provided by `platform/identity/terraform/`). Pass `cookie_domain` to share session cookies across multiple subdomains; pass `skip_path_regex` to bypass authentication on webhook or health-check paths.

## Usage

```hcl
module "backrest_forward_auth" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/authentik/traefik-forward-auth?ref=v2.0.0"

  application_name = "Backrest"
  application_slug = "backrest"
  external_host    = "https://backrest.example.org"
  cookie_domain    = "example.org"

  authorized_groups = {
    admin = var.base.authentik.groups["admin"]
  }
  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `application_name` | `string` | — | Display name shown in the Authentik user portal. |
| `application_slug` | `string` | — | URL-safe slug. Also used to name the per-app Authentik group. |
| `external_host` | `string` | — | External URL of the application being protected (e.g., `https://app.example.org`). Pass a full URL; the module never assembles subdomains. |
| `category_group` | `string` | `"Tools"` | Category shown in the user portal grid. Free text. |
| `launch_url` | `string` | `null` | Launch URL for the application. Defaults to `external_host`. |
| `icon_url` | `string` | `null` | Optional icon path or full URL. |
| `description` | `string` | `null` | Optional one-line app description. |
| `authorized_groups` | `map(string)` | — | Map of role-name → Authentik group ID. Keys MUST be static strings so `for_each` can plan before group UUIDs exist. One policy binding is created per entry. |
| `authentication_flow_uuid` | `string` | — | Authentication flow UUID. |
| `authorization_flow_uuid` | `string` | — | Authorization flow UUID. |
| `invalidation_flow_uuid` | `string` | — | Invalidation flow UUID. |
| `access_token_validity` | `string` | `"hours=24"` | Access token validity (Authentik duration syntax). |
| `cookie_domain` | `string` | `null` | Cookie domain for forward auth sessions (e.g., `example.org` to share session across `*.example.org`). |
| `skip_path_regex` | `string` | `""` | Regex pattern for paths that bypass authentication (e.g., `^/health$\|^/api/webhooks`). |
| `basic_auth_enabled` | `bool` | `false` | If true, pass through HTTP Basic Auth headers (for API access alongside browser-based forward auth). |

## Outputs

| Name | Description |
|------|-------------|
| `application_uuid` | UUID of the created application. |
| `application_group_id` | ID of the Authentik group created for this application. |
| `application_slug` | Slug of the created application. |
| `provider_id` | ID of the Proxy Provider. |
| `provider_name` | Name of the Proxy Provider. |
| `external_host` | External host URL protected by this provider. |
