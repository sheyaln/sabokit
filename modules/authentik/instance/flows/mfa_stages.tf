# MFA AUTHENTICATOR STAGES MODULE
# 
# This module defines all Multi-Factor Authentication stages that can be
# reused across different authentication and enrollment flows

## TOTP Configuration Stage
resource "authentik_stage_authenticator_totp" "shared_totp" {
  name          = "Code Generator"
  friendly_name = "Code Generator"
  digits        = 6
}

## WebAuthn Configuration Stage for Cross-Platform Authenticators  
resource "authentik_stage_authenticator_webauthn" "shared_webauthn_cross_platform" {
  name                     = "Authenticate with your device (Passkey)"
  user_verification        = "preferred"
  authenticator_attachment = "cross-platform"
  friendly_name            = "Authenticate with your device (Passkey)"
}

## Email Configuration Stage
resource "authentik_stage_authenticator_email" "shared_email" {
  name          = "One-Time Passcode via Email"
  friendly_name = "One-Time Passcode via Email"
  host          = var.smtp_host
  port          = var.smtp_port
  username      = var.smtp_username
  password      = var.smtp_password

  configure_flow = authentik_flow.email_authenticator_enrollment.uuid

  use_ssl             = true
  use_tls             = false
  use_global_settings = false
  timeout             = 30
  token_expiry        = "minutes=15"
  from_address        = local.gateway_email
  subject             = "Your ${var.organisation_name} One-Time Passcode"
  template            = "email/email_otp.html"
}

## MFA Validation Stage for Authentication
resource "authentik_stage_authenticator_validate" "mfa_validate_strict" {
  name                       = "MFA Validation - Strict"
  device_classes             = ["totp", "webauthn", "email"]
  last_auth_threshold        = "seconds=0"
  not_configured_action      = "configure"
  webauthn_user_verification = "preferred"

  configuration_stages = [
    authentik_stage_authenticator_totp.shared_totp.id,
    authentik_stage_authenticator_webauthn.shared_webauthn_cross_platform.id,
    authentik_stage_authenticator_email.shared_email.id,
  ]
}
