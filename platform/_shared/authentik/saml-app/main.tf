# Reusable SAML application module for Authentik.
#
# Creates:
#   - Standard SAML property mappings (email, given/family name, display name, UPN; optionally groups)
#   - A SAML provider
#   - An application backed by the provider
#   - A per-application Authentik group
#   - One policy binding per entry in var.authorized_groups
#   - SAML configuration stored in Scaleway Secret Manager (secrets.tf)

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
  meta_icon        = var.icon_url != "" ? var.icon_url : "default-logo.png"

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
  # Authentik's API enforces uniqueness on (policy, target, order) for UPDATE.
  # A hardcoded order=10 across all bindings means the 2nd binding onward
  # fails with HTTP 400 — and you can't reverse out of a partial apply
  # because the pre-check rejects both directions. Stagger via lex-ordered
  # key index so each binding lands in a distinct slot.
  order = 10 + index(keys(var.authorized_groups), each.key)
}
