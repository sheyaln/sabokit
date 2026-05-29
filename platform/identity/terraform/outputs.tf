# The base/authentik/ contract surface.
#
# A single structured map keeps the API diffable in one place and lets apps
# reference `var.base.authentik.flows.authentication_flow` instead of juggling
# a dozen flat inputs. Adding fields here is a minor version bump; removing or
# renaming a field is a major bump.
#
# api_url / api_token_secret_id are placeholders in this module — the consumer
# provisions the Authentik admin host + API token; both are passed through
# verbatim so apps that need to construct an authentik provider block can read
# them off `var.base.authentik` instead of plumbing extra variables.

variable "api_url" {
  description = "URL of the Authentik API (e.g. \"https://auth.example.org\"). Surfaced verbatim in the output so apps can build their own authentik provider blocks from var.base.authentik.api_url."
  type        = string
  default     = ""
}

variable "api_token_secret_id" {
  description = "Scaleway Secret Manager ID holding the Authentik admin API token. Surfaced verbatim in the output."
  type        = string
  default     = ""
}

output "authentik" {
  description = "Authentik platform handles for app bundles. See ARCHITECTURE.md for the contract."
  value = {
    api_url             = var.api_url
    api_token_secret_id = var.api_token_secret_id
    identity_domain     = var.identity_domain
    org_name            = var.org_name

    flows = {
      authentication_flow        = module.flows.authentication_flow_login
      authorization_flow         = module.flows.default_provider_authorization_implicit_consent_id
      invalidation_flow          = module.flows.default_provider_invalidation_flow_id
      password_reset_flow        = module.flows.password_reset_flow_uuid
      user_settings_flow         = module.flows.user_settings_flow_uuid
      unenrollment_flow          = module.flows.default_unenrollment_flow_uuid
      source_authentication_flow = module.flows.source_authentication_flow_uuid
      source_enrollment_flow     = module.flows.source_enrollment_flow_uuid
    }

    # Flat group_name → group ID. Bundles resolve their authorized_groups
    # name list against this map (base.authentik.groups[<name>]).
    groups = merge(
      local.slot_group_ids,
      { for k, g in authentik_group.extra : k => g.id },
    )

    admin_tier = var.admin_group_name

    sources = merge(
      var.enable_google_social_login ? { google = authentik_source_oauth.google[0].uuid } : {},
      var.enable_apple_social_login ? { apple = authentik_source_oauth.apple[0].uuid } : {},
    )

    # No outpost_id: the embedded outpost relocated to the application layer
    # (v1.0 — all forward-auth providers are app-tier, so the outpost + its
    # protocol_providers binding live where the providers are born). Apps bind
    # to it via the application layer's own authentik_outpost.embedded, not via
    # this output (nothing consumed base.authentik.outpost_id anyway).
    branding_assets_path = "${path.module}/assets"

    icon_base_url = local.effective_icon_base_url
  }
}
