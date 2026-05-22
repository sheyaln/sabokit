# REUSABLE SAML APP MODULE FOR AUTHENTIK
#
# This module creates:
# 1. An Authentik Application with SAML provider
# 2. SAML property mappings for assertions (email, name, groups)
# 3. Group bindings for hierarchical access control
# 4. SAML configuration stored in Scaleway Secret Manager

locals {
  target_groups = var.access_level == "admin" ? [var.group_ids.admin] : (
    var.access_level == "delegate" ? [var.group_ids.admin, var.group_ids.union_delegate] : (
      var.access_level == "treasurer" ? [var.group_ids.admin, var.group_ids.union_delegate, var.group_ids.union_treasurer] :
      [var.group_ids.admin, var.group_ids.union_delegate, var.group_ids.union_treasurer, var.group_ids.union_member]
    )
  )
}

# ── SAML Property Mappings ───────────────────────────────────────────────────

resource "authentik_property_mapping_provider_saml" "email" {
  name          = "${var.application_slug}-saml-email"
  saml_name     = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
  friendly_name = "Email"
  expression    = "return user.email"
}

resource "authentik_property_mapping_provider_saml" "first_name" {
  name          = "${var.application_slug}-saml-firstname"
  saml_name     = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"
  friendly_name = "Given Name"
  expression    = "return user.first_name"
}

resource "authentik_property_mapping_provider_saml" "last_name" {
  name          = "${var.application_slug}-saml-lastname"
  saml_name     = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"
  friendly_name = "Surname"
  expression    = "return user.last_name"
}

resource "authentik_property_mapping_provider_saml" "display_name" {
  name          = "${var.application_slug}-saml-displayname"
  saml_name     = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
  friendly_name = "Display Name"
  expression    = "return user.name"
}

resource "authentik_property_mapping_provider_saml" "username" {
  name          = "${var.application_slug}-saml-username"
  saml_name     = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"
  friendly_name = "UPN"
  expression    = "return user.username"
}

resource "authentik_property_mapping_provider_saml" "groups" {
  count         = var.include_groups_attribute ? 1 : 0
  name          = "${var.application_slug}-saml-groups"
  saml_name     = "http://schemas.xmlsoap.org/claims/Group"
  friendly_name = "Groups"
  expression    = "return [group.name for group in request.user.ak_groups.all()]"
}

locals {
  saml_property_mapping_ids = compact(concat(
    [authentik_property_mapping_provider_saml.email.id],
    [authentik_property_mapping_provider_saml.first_name.id],
    [authentik_property_mapping_provider_saml.last_name.id],
    [authentik_property_mapping_provider_saml.display_name.id],
    [authentik_property_mapping_provider_saml.username.id],
    authentik_property_mapping_provider_saml.groups[*].id
  ))
}

# ── SAML Provider ────────────────────────────────────────────────────────────

resource "authentik_provider_saml" "provider" {
  name                = "${var.application_name} SAML Provider"
  authorization_flow  = var.authorization_flow_uuid
  authentication_flow = var.authentication_flow_uuid
  invalidation_flow   = var.invalidation_flow_uuid

  acs_url    = var.saml_assertion_consumer_service_url
  audience   = var.saml_audience
  sp_binding = var.saml_service_provider_binding

  signing_kp = var.generate_rsa_signing_key ? authentik_certificate_key_pair.rsa_signing_key[0].id : data.authentik_certificate_key_pair.default.id

  digest_algorithm    = var.saml_digest_algorithm
  signature_algorithm = var.saml_signature_algorithm
  sign_assertion      = var.saml_sign_assertion

  name_id_mapping = var.saml_name_id_use_email ? authentik_property_mapping_provider_saml.email.id : var.saml_name_id_mapping

  default_relay_state = var.saml_default_relay_state

  property_mappings = local.saml_property_mapping_ids

  lifecycle {
    ignore_changes = [
      signing_kp,
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
  protocol_provider = authentik_provider_saml.provider.id

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
