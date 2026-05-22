# REUSABLE OIDC APP MODULE FOR AUTHENTIK
#
# This module creates:
# 1. An Authentik Application with an OAuth2/OIDC Provider
# 2. Per-scope property mappings for OpenID Connect claims
# 3. Group bindings for hierarchical access control
# 4. OIDC credentials stored in Scaleway Secret Manager

locals {
  target_groups = var.access_level == "admin" ? [var.group_ids.admin] : (
    var.access_level == "delegate" ? [var.group_ids.admin, var.group_ids.union_delegate] : (
      var.access_level == "treasurer" ? [var.group_ids.admin, var.group_ids.union_delegate, var.group_ids.union_treasurer] :
      [var.group_ids.admin, var.group_ids.union_delegate, var.group_ids.union_treasurer, var.group_ids.union_member]
    )
  )
}

# ── OIDC Scope Mappings ─────────────────────────────────────────────────────

resource "authentik_property_mapping_provider_scope" "openid" {
  count       = contains(var.oidc_scopes, "openid") ? 1 : 0
  name        = "${var.application_slug}-openid-scope"
  scope_name  = "openid"
  description = "OpenID Connect scope for ${var.application_name}"
  expression  = "return {}"
}

resource "authentik_property_mapping_provider_scope" "profile" {
  count       = contains(var.oidc_scopes, "profile") ? 1 : 0
  name        = "${var.application_slug}-profile-scope"
  scope_name  = "profile"
  description = "Profile scope for ${var.application_name}"
  expression  = <<-EOT
name = user.name.split(" ")
given_name = name[0]
family_name = name[-1]
return {
    "name": user.name,
    "given_name": given_name, 
    "family_name": family_name,
    "preferred_username": user.username,
    "nickname": user.username,
}
EOT
}

resource "authentik_property_mapping_provider_scope" "email" {
  count       = contains(var.oidc_scopes, "email") ? 1 : 0
  name        = "${var.application_slug}-email-scope"
  scope_name  = "email"
  description = "Email scope for ${var.application_name}"
  expression  = <<-EOT
return {
    "email": user.email,
    "email_verified": True
}
EOT
}

resource "authentik_property_mapping_provider_scope" "offline_access" {
  count       = contains(var.oidc_scopes, "offline_access") ? 1 : 0
  name        = "${var.application_slug}-offline-access-scope"
  scope_name  = "offline_access"
  description = "Offline access scope for ${var.application_name}"
  expression  = "return {}"
}

resource "authentik_property_mapping_provider_scope" "authentik_api" {
  count       = contains(var.oidc_scopes, "goauthentik.io/api") ? 1 : 0
  name        = "${var.application_slug}-authentik-api-scope"
  scope_name  = "goauthentik.io/api"
  description = "Authentik API access scope for ${var.application_name}"
  expression  = "return {}"
}

resource "authentik_property_mapping_provider_scope" "groups" {
  count       = contains(var.oidc_scopes, "groups") ? 1 : 0
  name        = "${var.application_slug}-groups-scope"
  scope_name  = "groups"
  description = "Groups scope for ${var.application_name} role mapping"
  expression  = <<-EOT
return {
    "groups": [group.name for group in request.user.ak_groups.all()],
    "groups_full": [{"name": group.name, "id": str(group.pk)} for group in request.user.ak_groups.all()]
}
EOT
}

resource "authentik_property_mapping_provider_scope" "vikunja_scope" {
  count       = contains(var.oidc_scopes, "vikunja_scope") ? 1 : 0
  name        = "${var.application_slug}-vikunja-scope"
  scope_name  = "vikunja_scope"
  description = "Vikunja team assignment scope for ${var.application_name}"
  expression  = <<-EOT
# Return vikunja_groups claim for automatic team assignment
# Each team needs a unique oidcID and a name

# Start with the main org team (all users get this)
teams = [
    {
        "name": "${var.vikunja_team_name}",
        "oidcID": "main-team",
        "description": "All ${var.vikunja_team_name} members"
    }
]

# Add Delegates team if user is in union-delegate group
user_groups = [g.name for g in request.user.ak_groups.all()]
if "union-delegate" in user_groups:
    teams.append({
        "name": "Delegates",
        "oidcID": "delegates-team",
        "description": "${var.vikunja_team_name} Delegates"
    })

return {"vikunja_groups": teams}
EOT
}

locals {
  scope_mapping_ids = compact(concat(
    authentik_property_mapping_provider_scope.openid[*].id,
    authentik_property_mapping_provider_scope.profile[*].id,
    authentik_property_mapping_provider_scope.email[*].id,
    authentik_property_mapping_provider_scope.offline_access[*].id,
    authentik_property_mapping_provider_scope.authentik_api[*].id,
    authentik_property_mapping_provider_scope.groups[*].id,
    authentik_property_mapping_provider_scope.vikunja_scope[*].id
  ))
}

# ── OIDC Provider ────────────────────────────────────────────────────────────

resource "authentik_provider_oauth2" "provider" {
  name               = "${var.application_name} Provider"
  client_id          = local.client_id
  client_secret      = local.client_secret
  client_type        = "confidential"
  authorization_flow = var.authorization_flow_uuid
  invalidation_flow  = var.invalidation_flow_uuid

  signing_key = var.generate_rsa_signing_key ? authentik_certificate_key_pair.rsa_signing_key[0].id : data.authentik_certificate_key_pair.default.id

  include_claims_in_id_token = true
  issuer_mode                = "per_provider"

  access_token_validity   = var.access_token_validity
  refresh_token_validity  = var.refresh_token_validity
  refresh_token_threshold = "seconds=0"

  logout_method = "backchannel"

  allowed_redirect_uris = var.redirect_uris

  property_mappings   = local.scope_mapping_ids
  authentication_flow = var.authentication_flow_uuid
  sub_mode            = var.sub_mode

  lifecycle {
    ignore_changes = [
      signing_key,
      client_secret,
    ]
  }
}

# ── Application + Group Bindings ─────────────────────────────────────────────

resource "authentik_group" "application" {
  name         = "app-${var.application_slug}"
  is_superuser = false

  attributes = jsonencode({
    description = "Users with access to ${var.application_name}"
  })
}

resource "authentik_application" "application" {
  name              = var.application_name
  slug              = var.application_slug
  protocol_provider = authentik_provider_oauth2.provider.id

  group = var.category_group

  meta_launch_url  = var.launch_url
  meta_description = var.description
  open_in_new_tab  = true
  meta_icon        = var.icon_url != null ? var.icon_url : "default-logo.png"

  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "admin_group" {
  target = authentik_application.application.uuid
  group  = var.group_ids.admin
  order  = 0
}

resource "authentik_policy_binding" "application_group" {
  target = authentik_application.application.uuid
  group  = authentik_group.application.id
  order  = 0
}

resource "authentik_policy_binding" "delegate_group" {
  count  = contains(["delegate", "member"], var.access_level) ? 1 : 0
  target = authentik_application.application.uuid
  group  = var.group_ids.union_delegate
  order  = 0
}

resource "authentik_policy_binding" "treasurer_group" {
  count  = contains(["treasurer", "delegate", "member"], var.access_level) ? 1 : 0
  target = authentik_application.application.uuid
  group  = var.group_ids.union_treasurer
  order  = 0
}

resource "authentik_policy_binding" "member_group" {
  count  = var.access_level == "member" ? 1 : 0
  target = authentik_application.application.uuid
  group  = var.group_ids.union_member
  order  = 0
}
