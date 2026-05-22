# oidc-app

Creates one OIDC application + OAuth2 provider in Authentik, plus a per-application Authentik group, one policy binding per group in `authorized_group_ids`, and a Scaleway secret holding the generated client credentials. Property mappings for the standard OIDC scopes (`openid`, `profile`, `email`, `groups`, etc.) are emitted as `authentik_property_mapping_provider_scope` resources when the scope is listed in `oidc_scopes`.

Use `additional_property_mapping_ids` to inject app-specific custom scopes without forking the module. Use `generate_rsa_signing_key = true` to give the provider a dedicated signing certificate instead of Authentik's default self-signed pair.

## Usage

```hcl
module "outline_oidc" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/authentik/oidc-app?ref=v1.0.0"

  application_name = "Outline"
  application_slug = "outline"

  redirect_uris = [{
    url = "https://wiki.example.org/auth/oidc.callback"
  }]

  authorized_group_ids     = [var.base.authentik.groups["member"]]
  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `application_name` | `string` | — | Display name shown in the Authentik user portal. |
| `application_slug` | `string` | — | URL-safe slug. Also used to name the per-app Authentik group and Scaleway secret. |
| `category_group` | `string` | `"Tools"` | Category shown in the user portal grid. Free text. |
| `redirect_uris` | `list(object({ matching_mode?, url }))` | — | Allowed redirect URIs for the OIDC provider. Pass full URLs; the module never assembles subdomains. |
| `launch_url` | `string` | `null` | Optional launch URL shown in the user portal. Defaults to Authentik's first-redirect-uri behaviour. |
| `icon_url` | `string` | `null` | Optional icon path (relative to Authentik media, e.g. `outline-icon.png`) or full URL. |
| `description` | `string` | `null` | Optional one-line app description shown in the user portal. |
| `authorized_group_ids` | `list(string)` | — | Authentik group IDs allowed to access this application. The module creates one policy binding per group. |
| `oidc_scopes` | `list(string)` | `["openid", "profile", "email", "groups"]` | OIDC scopes the provider will expose. Defaults cover the common set; pass a different list to opt out of any. |
| `additional_property_mapping_ids` | `list(string)` | `[]` | IDs of property mappings the consumer wants attached to the provider in addition to the built-in scope mappings. Use this to inject app-specific custom scopes. |
| `access_token_validity` | `string` | `"minutes=10"` | Access token validity (Authentik duration syntax, e.g. `minutes=10`, `hours=1`). |
| `refresh_token_validity` | `string` | `"days=30"` | Refresh token validity (Authentik duration syntax). |
| `sub_mode` | `string` | `"user_email"` | OIDC sub claim mode. `user_email`, `user_id`, `user_uuid`, or `hashed_user_id`. |
| `authentication_flow_uuid` | `string` | — | Authentication flow UUID. From `base.authentik.flows.authentication_flow`. |
| `authorization_flow_uuid` | `string` | — | Authorization flow UUID. From `base.authentik.flows.authorization_flow`. |
| `invalidation_flow_uuid` | `string` | — | Invalidation flow UUID. From `base.authentik.flows.invalidation_flow`. |
| `generate_rsa_signing_key` | `bool` | `false` | If true, generate a dedicated RSA signing key for this app. Otherwise use the Authentik default self-signed certificate. |
| `signing_key_subject` | `object({ common_name, organization })` | `{ common_name = "authentik.example.org", organization = "Federated Commons" }` | Subject for the RSA signing certificate when `generate_rsa_signing_key` is true. Object with `common_name` and `organization`. |

## Outputs

| Name | Description |
|------|-------------|
| `application_uuid` | UUID of the created application. |
| `application_slug` | Slug of the created application. |
| `application_group_id` | ID of the per-app Authentik group (used for service accounts that need direct access). |
| `provider_id` | ID of the OIDC provider. |
| `client_id` | OIDC client ID. |
| `client_secret` | OIDC client secret. Prefer reading from `scaleway_secret_id` when possible. |
| `scaleway_secret_id` | ID of the Scaleway secret holding OIDC credentials. Consumers (typically Ansible) should fetch from here rather than embedding the values in Terraform state. |
