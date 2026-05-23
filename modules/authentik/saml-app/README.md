# saml-app

Creates one SAML application + provider in Authentik, plus standard SAML property mappings (email, given/family name, display name, UPN; optionally groups), a per-application Authentik group, one policy binding per entry in `authorized_groups`, and a Scaleway secret holding the SAML configuration.

`authorized_groups` is a `map(string)` keyed by static role names (e.g. `admin`, `member`) so the underlying `for_each` plans cleanly even when the group UUIDs themselves are not yet known.

The module emits the metadata/SSO/SLO URL paths as outputs (relative to the Authentik host) so consumers can hand them to the service provider during configuration. Use `generate_rsa_signing_key = true` to give the provider a dedicated signing certificate instead of Authentik's default self-signed pair.

## Usage

```hcl
module "nextcloud_saml" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/authentik/saml-app?ref=v2.1.0"

  application_name = "Nextcloud"
  application_slug = "nextcloud"

  saml_assertion_consumer_service_url = "https://cloud.example.org/apps/user_saml/saml/acs"
  saml_audience                       = "https://cloud.example.org/apps/user_saml/saml/metadata"

  authorized_groups = {
    member = var.base.authentik.groups["member"]
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
| `application_slug` | `string` | — | URL-safe slug. Also used to name the per-app Authentik group and Scaleway secret. |
| `category_group` | `string` | `"Tools"` | Category shown in the user portal grid. Free text. |
| `launch_url` | `string` | `null` | Optional launch URL shown in the user portal. |
| `icon_url` | `string` | `null` | Optional icon path (relative to Authentik media) or full URL. |
| `description` | `string` | `null` | Optional one-line app description shown in the user portal. |
| `authorized_groups` | `map(string)` | — | Map of role-name → Authentik group ID. Keys MUST be static strings so `for_each` can plan before group UUIDs exist. One policy binding is created per entry. |
| `authentication_flow_uuid` | `string` | — | Authentication flow UUID. |
| `authorization_flow_uuid` | `string` | — | Authorization flow UUID. |
| `invalidation_flow_uuid` | `string` | — | Invalidation flow UUID. |
| `generate_rsa_signing_key` | `bool` | `false` | If true, generate a dedicated RSA signing key for SAML assertions. Otherwise use the Authentik default self-signed certificate. |
| `signing_key_subject` | `object({ common_name, organization })` | `{ common_name = "authentik.example.org", organization = "Federated Commons" }` | Subject for the RSA signing certificate when `generate_rsa_signing_key` is true. |
| `saml_assertion_consumer_service_url` | `string` | — | SAML Assertion Consumer Service (ACS) URL on the service provider side. Pass a full URL; the module never assembles subdomains. |
| `saml_audience` | `string` | — | SAML audience / entity ID expected by the service provider. |
| `saml_service_provider_binding` | `string` | `"redirect"` | SAML service provider binding. `redirect` or `post`. |
| `saml_name_id_mapping` | `string` | `null` | Property mapping ID for the SAML NameID. Defaults to Authentik's default if null. Ignored when `saml_name_id_use_email = true`. |
| `saml_name_id_use_email` | `bool` | `false` | If true, use the email property mapping as the SAML NameID. |
| `saml_digest_algorithm` | `string` | `"http://www.w3.org/2001/04/xmlenc#sha256"` | SAML digest algorithm. |
| `saml_signature_algorithm` | `string` | `"http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"` | SAML signature algorithm. |
| `saml_sign_assertion` | `bool` | `true` | Whether to sign SAML assertions. |
| `saml_default_relay_state` | `string` | `null` | Optional default relay state passed to the SP. |
| `include_groups_attribute` | `bool` | `true` | Whether to include the SAML groups attribute mapping in assertions. |

## Outputs

| Name | Description |
|------|-------------|
| `application_uuid` | UUID of the created application. |
| `application_slug` | Slug of the created application. |
| `application_group_id` | ID of the per-app Authentik group. |
| `provider_id` | ID of the SAML provider. |
| `saml_metadata_url_path` | SAML metadata URL path (append to `https://<authentik-host>`). |
| `saml_sso_url_path` | SAML SSO URL path (append to `https://<authentik-host>`). |
| `saml_slo_url_path` | SAML SLO URL path (append to `https://<authentik-host>`). |
| `scaleway_secret_id` | ID of the Scaleway secret holding SAML configuration. |
