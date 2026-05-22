# FLOWS MODULE OUTPUTS

# Custom Flow Outputs
output "authentication_flow_username_and_passkey_slug" {
  description = "The slug of the local authentication flow"
  value       = authentik_flow.authentication_flow_username_and_passkey.slug
}

output "authentication_flow_login" {
  description = "The UUID of the local authentication flow (operational default)"
  value       = authentik_flow.authentication_flow_username_and_passkey.uuid
}

# Default Flow Data Source Outputs
output "default_source_authentication_id" {
  description = "ID of the default source authentication flow"
  value       = data.authentik_flow.default-source-authentication.id
}

output "default_source_enrollment_id" {
  description = "ID of the default source enrollment flow"
  value       = data.authentik_flow.default-source-enrollment.id
}

output "default_invalidation_flow_id" {
  description = "ID of the default invalidation flow"
  value       = data.authentik_flow.default-invalidation-flow.id
}

output "default_provider_invalidation_flow_id" {
  description = "ID of the default provider invalidation flow"
  value       = data.authentik_flow.default-provider-invalidation-flow.id
}

output "default_user_settings_flow_id" {
  description = "ID of the default user settings flow"
  value       = data.authentik_flow.default-user-settings-flow.id
}

output "default_provider_authorization_implicit_consent_id" {
  description = "ID of the default provider authorization implicit consent flow"
  value       = data.authentik_flow.default-provider-authorization-implicit-consent.id
}

output "manual_enrollment_flow_id" {
  description = "ID of the manual enrollment flow"
  value       = authentik_flow.manual_enrollment.id
}

output "manual_enrollment_flow_uuid" {
  description = "UUID of the manual enrollment flow"
  value       = authentik_flow.manual_enrollment.uuid
}

output "manual_enrollment_flow_slug" {
  description = "Slug of the manual enrollment flow"
  value       = authentik_flow.manual_enrollment.slug
}

output "default_unenrollment_flow_id" {
  description = "ID of the default unenrollment flow"
  value       = authentik_flow.default_unenrollment_flow.id
}
output "default_unenrollment_flow_uuid" {
  description = "UUID of the default unenrollment flow"
  value       = authentik_flow.default_unenrollment_flow.uuid
}

# Unenrollment Flow Outputs
output "unenrollment_flow_slug" {
  description = "Slug for the user unenrollment flow"
  value       = authentik_flow.default_unenrollment_flow.slug
}

output "unenrollment_flow_uuid" {
  description = "UUID for the user unenrollment flow"
  value       = authentik_flow.default_unenrollment_flow.uuid
}

# Source Authentication Flow Outputs
output "source_authentication_flow_uuid" {
  description = "UUID of the source authentication flow for social logins"
  value       = authentik_flow.source_authentication.uuid
}

output "source_authentication_flow_slug" {
  description = "Slug of the source authentication flow for social logins"
  value       = authentik_flow.source_authentication.slug
}

# Source Enrollment Flow Outputs
output "source_enrollment_flow_uuid" {
  description = "UUID of the source enrollment flow (passwordless)"
  value       = authentik_flow.source_enrollment.uuid
}

output "source_enrollment_flow_slug" {
  description = "Slug of the source enrollment flow (passwordless)"
  value       = authentik_flow.source_enrollment.slug
}

output "password_reset_flow_id" {
  description = "ID of the email password reset flow"
  value       = authentik_flow.password_reset_flow.id
}

output "password_reset_flow_uuid" {
  description = "UUID of the email password reset flow"
  value       = authentik_flow.password_reset_flow.uuid
}

output "user_invitation_flow_id" {
  description = "ID of the email invitation flow"
  value       = authentik_flow.user_invitation_flow.id
}

output "user_invitation_flow_uuid" {
  description = "UUID of the email invitation flow"
  value       = authentik_flow.user_invitation_flow.uuid
}

output "mfa_reset_flow_id" {
  description = "ID of the email MFA reset flow"
  value       = authentik_flow.mfa_reset_flow.id
}

output "mfa_reset_flow_uuid" {
  description = "UUID of the email MFA reset flow"
  value       = authentik_flow.mfa_reset_flow.uuid
}

output "invitation_flow_slug" {
  value       = authentik_flow.user_invitation_flow.slug
  description = "Slug for the user invitation flow"
}

output "invitation_email_stage_id" {
  value       = authentik_stage_email.send_user_invitation.id
  description = "ID of the invitation email stage (for sending invitations)"
}

# Email Authenticator Enrollment Flow Outputs
output "email_authenticator_enrollment_flow_slug" {
  description = "Slug of the email authenticator enrollment flow"
  value       = authentik_flow.email_authenticator_enrollment.slug
}

output "email_authenticator_enrollment_flow_uuid" {
  description = "UUID of the email authenticator enrollment flow"
  value       = authentik_flow.email_authenticator_enrollment.uuid
}