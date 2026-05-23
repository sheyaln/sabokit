# bookmark

Creates an Authentik application with no protocol provider — it shows up in the user portal as a link to an external URL. Used to surface external services that integrate with the Authentik identity but don't authenticate through it.

The module still creates one `authentik_policy_binding` per entry in `authorized_groups`, so visibility is gated on directory membership even though no token is issued.

`authorized_groups` is a `map(string)` keyed by static role names (e.g. `admin`, `member`) so the underlying `for_each` plans cleanly even when the group UUIDs themselves are not yet known.

## Usage

```hcl
module "status_page_bookmark" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/authentik/bookmark?ref=v2.0.0"

  application_name = "Status Page"
  application_slug = "status-page"
  launch_url       = "https://status.example.org"
  authorized_groups = {
    member = var.base.authentik.groups["member"]
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `application_name` | `string` | — | Display name shown in the Authentik user portal. |
| `application_slug` | `string` | — | URL-safe slug. |
| `category_group` | `string` | `"Resources"` | Category shown in the user portal grid. Free text. |
| `launch_url` | `string` | — | URL the bookmark opens (required for bookmarks). Pass a full URL. |
| `icon_url` | `string` | `null` | Optional icon path or full URL. |
| `description` | `string` | `null` | Optional one-line bookmark description. |
| `authorized_groups` | `map(string)` | — | Map of role-name → Authentik group ID. Keys MUST be static strings so `for_each` can plan before group UUIDs exist. One policy binding is created per entry. |
| `open_in_new_tab` | `bool` | `true` | Whether the bookmark opens in a new browser tab. |

## Outputs

| Name | Description |
|------|-------------|
| `application_uuid` | UUID of the created bookmark application. |
| `application_slug` | Slug of the created bookmark application. |
| `application_name` | Name of the created bookmark application. |
| `launch_url` | Launch URL of the bookmark application. |
