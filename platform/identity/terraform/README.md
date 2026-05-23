# platform/identity/terraform

The Authentik configuration module. Every consumer calls this once after
the identity bootstrap to produce a working Authentik instance — flows,
brand, base groups, optional social sources, and an embedded outpost ready
to bind forward-auth providers from `apps/*`.

This module is the source of truth for the **group taxonomy** and the **flow
identifiers** that every app bundle in `apps/*` references via
`var.base.authentik.groups[...]` and `var.base.authentik.flows.*`.

See [`ARCHITECTURE.md`](../../ARCHITECTURE.md) for the full base/app contract.

## What this provisions

- A default brand bound to `var.gateway_domain` with custom CSS and the
  branding asset filenames you pass in.
- The standard flow set (authentication, source-auth, source-enrollment,
  manual enrollment, password reset, MFA reset, email-invitation, user
  unenrollment) — see `flows/`.
- Base groups: `admin` (always), `member` (always), and `delegate` (optional,
  with a paired RBAC role for user/group management). Plus any extras the
  consumer adds via `var.extra_groups`.
- Optional Google and Apple OAuth social-login sources (each gated by a
  toggle and a Scaleway secret lookup).
- A configured embedded outpost that binds whatever forward-auth provider IDs
  the consumer passes in `var.extra_forward_auth_provider_ids`.
- Generic user-lifecycle notifications: events fire on user
  create/activate, emails go to the admin-tier group(s), and an optional
  webhook gets POST'd JSON for downstream wiring (chat, ticketing, etc.).

## Inputs

The full input set is documented in `variables.tf`. The minimum required is:

| Input            | Why                                                  |
|------------------|------------------------------------------------------|
| `gateway_domain` | Hostname the Authentik admin/portal answers on       |
| `base_domain`    | Apps domain (used in flow titles and email bodies)   |
| `org_name`       | Organization display name                            |
| `org_slug`       | URL-safe slug                                        |
| `infra_email`    | Operations contact email                             |

Everything else has a sensible default. To use social login, set
`enable_google_social_login = true` and/or `enable_apple_social_login = true`
and provision the corresponding Scaleway secret
(`social-google-oauth-credentials` / `social-apple-oauth-credentials`).

## Output: `authentik`

```hcl
output "authentik" = {
  api_url              = string
  api_token_secret_id  = string
  gateway_domain       = string
  org_name             = string
  flows = {
    authentication_flow        = string  # UUID
    authorization_flow         = string  # UUID
    invalidation_flow          = string  # UUID
    password_reset_flow        = string  # UUID
    user_settings_flow         = string  # UUID
    unenrollment_flow          = string  # UUID
    source_authentication_flow = string  # UUID
    source_enrollment_flow     = string  # UUID
  }
  groups               = map(string)  # "admin" | "member" | "delegate" | extras → group ID
  sources              = map(string)  # "google" | "apple" → source UUID (may be {})
  outpost_id           = string
  branding_assets_path = string       # filesystem path consumed by ansible
}
```

Apps consume this via `var.base.authentik.*`. The string keys in `groups` are
the canonical names apps look up — keep them stable across forks.

## Integration with `base/scaleway`

`base/scaleway/` outputs `domains.gateway_domain` and `domains.base_domain`;
wire them through to this module.

## SMTP (optional)

`smtp_secret_name` defaults to `""` — SMTP is **off by default**. The
identity bundle still creates every email stage (password reset, MFA reset,
invitation send/verify, manual enrollment verify, Email OTP authenticator)
but flips them to `use_global_settings = true` with null SMTP fields. Plan
and apply succeed without any Scaleway secret existing; any user-facing
email step at runtime no-ops cleanly until SMTP is wired.

To turn SMTP on, create a Scaleway secret in the consumer's project with the
JSON shape `{smtp_host, smtp_port, smtp_username, smtp_password}`, then set
`smtp_secret_name = "<that-secret>"` and re-apply. The stages flip to
`use_global_settings = false` and start sending.

## Outpost binding

Apps that need Traefik forward-auth (Backrest, BentoPDF, anything proxied)
export `authentik_provider_id` from their bundle. The consumer assembles
those IDs and passes them to this module via
`extra_forward_auth_provider_ids = compact([...])`. See the
"Outpost binding mechanism" section of `ARCHITECTURE.md` for the wiring and
the first-apply cycle note.

## Layout

```
platform/identity/terraform/
├── versions.tf           # Required providers
├── variables.tf          # Module inputs
├── locals.tf             # Derived values (notification target groups, etc.)
├── data.tf               # Scaleway secret lookups (SMTP + optional socials)
├── brand.tf              # Default brand resource
├── user_groups.tf        # admin / member / extra groups
├── roles.tf              # delegate RBAC role + group
├── auth_sources.tf       # Google + Apple sources (toggle-gated)
├── flows.tf              # Calls the flows submodule
├── flows/                # The flow stages, prompts, and email stages
├── expressions/          # Python expression policy templates
├── assets/               # Branding CSS + AUP / welcome HTML templates
├── notifications.tf      # User-lifecycle event wiring
├── outpost.tf            # Embedded outpost + forward-auth binding
├── ui_prompts.tf         # Placeholder for future UI prompt definitions
├── outputs.tf            # The contract output "authentik"
└── README.md             # This file
```
