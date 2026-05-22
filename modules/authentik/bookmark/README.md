# bookmark

Creates an Authentik application with no protocol provider — it shows up in the user portal as a link to an external URL. Used to surface external services that integrate with the Authentik identity but don't authenticate through it.

The module still creates one `authentik_policy_binding` per group in `authorized_group_ids`, so visibility is gated on directory membership even though no token is issued.

## Usage

```hcl
module "status_page_bookmark" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/authentik/bookmark?ref=v1.0.0"

  application_name     = "Status Page"
  application_slug     = "status-page"
  launch_url           = "https://status.example.org"
  authorized_group_ids = [var.base.authentik.groups["member"]]
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
| `authorized_group_ids` | `list(string)` | — | Authentik group IDs allowed to see this bookmark. The module creates one policy binding per group. |
| `open_in_new_tab` | `bool` | `true` | Whether the bookmark opens in a new browser tab. |

## Outputs

| Name | Description |
|------|-------------|
| `application_uuid` | UUID of the created bookmark application. |
| `application_slug` | Slug of the created bookmark application. |
| `application_name` | Name of the created bookmark application. |
| `launch_url` | Launch URL of the bookmark application. |
