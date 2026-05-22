# AUTHENTICATION STAGES MODULE
# 
# This module defines authentication stages for identification, password,
# and user login that can be reused across flows

## User Identification Stage for Alternative Flow (Username + Passkey)
resource "authentik_stage_identification" "username_passkey_identification" {
  name                      = "User Identification - Username and Passkey"
  user_fields               = ["email"]
  case_insensitive_matching = true
  show_matched_user         = true
  show_source_labels        = true
  pretend_user_exists       = true
  enable_remember_me        = false # Disabled - 30-day session is default


  enrollment_flow = authentik_flow.manual_enrollment.uuid
  recovery_flow   = authentik_flow.password_reset_flow.uuid

  # Social login sources
  sources = [
    var.google_social_login_uuid,
    var.apple_social_login_uuid
  ]
}

## Password Stage for Alternative Flow
resource "authentik_stage_password" "username_passkey_password" {
  name = "Password Authentication - Username and Passkey"
  backends = [
    "authentik.core.auth.InbuiltBackend",
    "authentik.sources.ldap.auth.LDAPBackend",
    "authentik.core.auth.TokenBackend",
  ]
  allow_show_password = true

}

## Shared User Login Stage
resource "authentik_stage_user_login" "shared_user_login" {
  name             = "User Login Complete"
  session_duration = "days=30"
  geoip_binding    = "bind_continent_country_city"
  network_binding  = "bind_asn"
}
