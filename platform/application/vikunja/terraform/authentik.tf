module "authentik" {
  source = "../../../_shared/authentik/oidc-app"
  count  = var.enabled ? 1 : 0

  application_name = var.application_name
  application_slug = local.application_slug
  category_group   = var.category_group
  icon_url         = local.effective_icon_url
  description      = "Task and project tracker"
  launch_url       = local.app_url

  redirect_uris = [{
    matching_mode = "strict"
    url           = local.oidc_callback_url
  }]

  authorized_groups = local.authorized_groups

  # Standard OIDC scopes cover identity. The custom team-claim scope is added
  # via additional_property_mapping_ids so Vikunja's team auto-provisioning
  # (vikunja_groups claim, see authentik_property_mapping_provider_scope below)
  # rides alongside without colliding with the stock `groups` scope.
  oidc_scopes                     = ["openid", "profile", "email"]
  additional_property_mapping_ids = [authentik_property_mapping_provider_scope.vikunja_team_claim[0].id]
  sub_mode                        = "user_email"

  access_token_validity  = "hours=1"
  refresh_token_validity = "days=30"

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow

}

# Vikunja's team auto-provisioning reads the `vikunja_groups` claim and expects
# `[{name, oidcID}, ...]` per https://vikunja.io/docs/openid/. Name + oidcID are
# required; description + isPublic are optional. We emit every Authentik group
# the user belongs to — Vikunja creates one team per group on first login and
# reconciles membership on every subsequent token exchange. To restrict which
# groups produce teams, manage that via Authentik group membership upstream;
# this expression intentionally surfaces all groups so operators don't lose
# granularity at the claim layer.
resource "authentik_property_mapping_provider_scope" "vikunja_team_claim" {
  count       = var.enabled ? 1 : 0
  name        = "${local.application_slug}-vikunja-team-claim"
  scope_name  = var.oidc_groups_scope_name
  description = "Vikunja team auto-provisioning claim for ${var.application_name}"
  expression  = <<-EOT
    return {
        "vikunja_groups": [
            {"name": group.name, "oidcID": str(group.pk)}
            for group in request.user.ak_groups.all()
        ]
    }
  EOT
}
