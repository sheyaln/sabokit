# Reusable OIDC application module for Authentik.
#
# Creates:
#   - An OAuth2/OIDC provider with standard scope mappings (and any
#     consumer-supplied additional property mappings)
#   - An application backed by the provider
#   - A per-application Authentik group (authorized via the app itself)
#   - One policy binding per entry in var.authorized_groups
#   - OIDC client credentials stored in Scaleway Secret Manager (secrets.tf)

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
  description = "Groups scope for ${var.application_name}"
  expression  = <<-EOT
return {
    "groups": [group.name for group in request.user.ak_groups.all()],
    "groups_full": [{"name": group.name, "id": str(group.pk)} for group in request.user.ak_groups.all()]
}
EOT
}

locals {
  builtin_scope_mapping_ids = compact(concat(
    authentik_property_mapping_provider_scope.openid[*].id,
    authentik_property_mapping_provider_scope.profile[*].id,
    authentik_property_mapping_provider_scope.email[*].id,
    authentik_property_mapping_provider_scope.offline_access[*].id,
    authentik_property_mapping_provider_scope.authentik_api[*].id,
    authentik_property_mapping_provider_scope.groups[*].id,
  ))
  all_property_mapping_ids = concat(local.builtin_scope_mapping_ids, var.additional_property_mapping_ids)
}

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

  property_mappings   = local.all_property_mapping_ids
  authentication_flow = var.authentication_flow_uuid
  sub_mode            = var.sub_mode

  lifecycle {
    ignore_changes = [
      signing_key,
      client_secret,
    ]
  }
}

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

resource "authentik_policy_binding" "application_group" {
  target = authentik_application.application.uuid
  group  = authentik_group.application.id
  order  = 0
}

resource "authentik_policy_binding" "authorized" {
  for_each = var.authorized_groups

  target = authentik_application.application.uuid
  group  = each.value
  order  = 10
}
