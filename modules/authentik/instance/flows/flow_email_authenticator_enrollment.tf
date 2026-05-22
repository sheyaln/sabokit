# EMAIL AUTHENTICATOR ENROLLMENT FLOW
#
# Lets authenticated users enroll the Email OTP authenticator from a dedicated
# flow that can be linked in the UI or invoked by policies.

resource "authentik_flow" "email_authenticator_enrollment" {
  name               = "Enroll Email Authenticator"
  title              = "Enroll Email One-Time Passcode"
  slug               = "enroll-email-authenticator"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  policy_engine_mode = "any"
  compatibility_mode = true
  denied_action      = "message_continue"
  background         = var.flow_background
}

resource "authentik_flow_stage_binding" "email_authenticator_enrollment_binding" {
  target = authentik_flow.email_authenticator_enrollment.uuid
  stage  = authentik_stage_authenticator_email.shared_email.id
  order  = 10

  policy_engine_mode      = "any"
  invalid_response_action = "retry"
  re_evaluate_policies    = true
}


