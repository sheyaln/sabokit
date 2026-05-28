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

    # Flat group_name → group ID. Apps not using the cascade read
    # base.authentik.groups[var.access_level] (default access_level is a
    # group_name, not a peer_name).
    groups = merge(
      local.slot_group_ids,
      { for k, g in authentik_group.extra : k => g.id },
    )

    # peer_name → map(group_name → group_id) of every group an app scoped to
    # that peer should bind. The inner map is { the peer's own group } merged
    # with { every peer-group in every strictly-higher slot }. Bundles with
    # tier_cascade_enabled = true consume
    # base.authentik.tier_cascade[var.tier_access_level] directly for their
    # authorized_groups. See platform/identity/terraform/README.md for the
    # cascade-up worked example.
    tier_cascade = local.tier_cascade
    admin_tier   = var.admin_group_name

    sources = merge(
      var.enable_google_social_login ? { google = authentik_source_oauth.google[0].uuid } : {},
      var.enable_apple_social_login ? { apple = authentik_source_oauth.apple[0].uuid } : {},
    )

    # Always source outpost_id from the data source — never the managed
    # resource. Both point at the same singleton Authentik outpost (the
    # built-in "authentik Embedded Outpost"), so their UUIDs are equal.
    # Referencing the managed resource creates a static graph cycle:
    #   output.authentik -> resource.authentik_outpost.embedded
    #     -> var.extra_forward_auth_provider_ids
    #     -> (consumer's compact() list)
    #     -> module.<app>.authentik_provider_id
    #     -> module.<app>.var.base
    #     -> local.base.authentik (this output)
    # Sourcing the id from the data source breaks the edge from output to
    # resource without losing any functionality — the resource still
    # exists, still attaches providers, terraform still applies it.
    outpost_id           = data.authentik_outpost.embedded.id
    branding_assets_path = "${path.module}/assets"

    icon_base_url = local.effective_icon_base_url
  }
}
