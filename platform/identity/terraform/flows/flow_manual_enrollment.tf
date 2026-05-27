# MANUAL ENROLLMENT FLOW (Default two-prompt flow)

# Main Manual Enrollment Flow
resource "authentik_flow" "manual_enrollment" {
  name               = "${var.organisation_name} Manual Enrollment"
  title              = "Join ${var.organisation_name}"
  slug               = "manual-enrollment"
  designation        = "enrollment"
  authentication     = "require_unauthenticated"
  layout             = "stacked"
  policy_engine_mode = "any"
  compatibility_mode = true
  denied_action      = "message_continue"
  background         = var.flow_background
}

# PROMPT FIELDS

# Name field
resource "authentik_stage_prompt_field" "manual_enrollment_name" {
  name                   = "manual-enrollment-field-name"
  field_key              = "name"
  label                  = "Chosen Name"
  type                   = "text"
  required               = true
  placeholder            = "Name"
  placeholder_expression = false
  order                  = 1
}

# Email field
resource "authentik_stage_prompt_field" "manual_enrollment_email" {
  name                   = "manual-enrollment-field-email"
  field_key              = "email"
  label                  = "Email"
  type                   = "email"
  required               = true
  placeholder            = "Email"
  placeholder_expression = false
  order                  = 2
}

# Password field
resource "authentik_stage_prompt_field" "manual_enrollment_password" {
  name                   = "manual-enrollment-field-password"
  field_key              = "password"
  label                  = "Password"
  type                   = "password"
  required               = true
  placeholder            = "Password"
  placeholder_expression = false
  order                  = 4
}

# Password repeat field
resource "authentik_stage_prompt_field" "manual_enrollment_password_repeat" {
  name                   = "manual-enrollment-field-password-repeat"
  field_key              = "password_repeat"
  label                  = "Password (repeat)"
  type                   = "password"
  required               = true
  placeholder            = "Password (repeat)"
  placeholder_expression = false
  order                  = 5
}

# Member ID field — optional, mirrors source-enrollment's member_id prompt so
# manual + social enrollees populate the same user.attributes['member_id']
# downstream automations key off. Bare field_key (no `attributes.` prefix);
# user_write writes non-User-model prompt_data keys into attributes
# automatically, matching source-enrollment's shape.
resource "authentik_stage_prompt_field" "manual_enrollment_member_id" {
  name                   = "manual-enrollment-field-member-id"
  field_key              = "member_id"
  label                  = var.member_id_label
  type                   = "text"
  required               = false
  placeholder            = ""
  placeholder_expression = false
  order                  = 3
}

# STAGES

# Single prompt stage - All fields
resource "authentik_stage_prompt" "manual_enrollment_prompt_all" {
  name = "manual-enrollment-prompt-all"

  fields = [
    authentik_stage_prompt_field.manual_enrollment_name.id,
    authentik_stage_prompt_field.manual_enrollment_email.id,
    authentik_stage_prompt_field.manual_enrollment_member_id.id,
    authentik_stage_prompt_field.manual_enrollment_password.id,
    authentik_stage_prompt_field.manual_enrollment_password_repeat.id,
  ]

  validation_policies = [
    authentik_policy_expression.shared_member_id_normalize.id,
    authentik_policy_expression.shared_member_id_unique.id,
  ]
}

# Welcome prompt stage
resource "authentik_stage_prompt" "manual_enrollment_welcome" {
  name = "manual-enrollment-welcome"
  fields = [
    authentik_stage_prompt_field.shared_welcome_message.id,
  ]
}

# User Write Stage - Create the user account (inactive for email verification)
resource "authentik_stage_user_write" "manual_enrollment_user_write" {
  name                     = "manual-enrollment-user-write"
  create_users_as_inactive = true
  create_users_group       = var.member_group_id
  user_type                = "internal"
  user_creation_mode       = "always_create"
  user_path_template       = "users" # Store all users under "users" path
}

# Email Verification Stage
resource "authentik_stage_email" "manual_enrollment_email_verification" {
  name                = "manual-enrollment-email-verification"
  use_global_settings = !var.smtp_enabled
  # When smtp_enabled is false, host/port/from_address/username match the server-side
  # defaults the Authentik API back-fills, which otherwise cause perpetual drift.
  host                     = var.smtp_enabled ? var.smtp_host : "localhost"
  port                     = var.smtp_enabled ? var.smtp_port : 25
  username                 = var.smtp_enabled ? var.smtp_username : ""
  password                 = var.smtp_enabled ? var.smtp_password : null
  use_tls                  = false
  use_ssl                  = true
  timeout                  = 30
  from_address             = var.smtp_enabled ? local.gateway_email : "system@authentik.local"
  subject                  = "Verify your email address - ${var.organisation_name} Gateway"
  template                 = "email/account_confirmation.html"
  activate_user_on_success = false
}

# User Login Stage - Complete enrollment
resource "authentik_stage_user_login" "manual_enrollment_user_login" {
  name = "manual-enrollment-user-login"
}

# FLOW STAGE BINDINGS

# Step 1: All fields prompt
resource "authentik_flow_stage_binding" "manual_enrollment_prompt_all_binding" {
  target               = authentik_flow.manual_enrollment.uuid
  stage                = authentik_stage_prompt.manual_enrollment_prompt_all.id
  order                = 10
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# Step 2: Acceptable Use Policy
resource "authentik_flow_stage_binding" "manual_enrollment_aup_binding" {
  target               = authentik_flow.manual_enrollment.uuid
  stage                = authentik_stage_prompt.shared_aup.id
  order                = 15
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# Step 3: Create User Account
resource "authentik_flow_stage_binding" "manual_enrollment_user_write_binding" {
  target               = authentik_flow.manual_enrollment.uuid
  stage                = authentik_stage_user_write.manual_enrollment_user_write.id
  order                = 20
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

# Step 4: Email Verification
resource "authentik_flow_stage_binding" "manual_enrollment_email_verification_binding" {
  target               = authentik_flow.manual_enrollment.uuid
  stage                = authentik_stage_email.manual_enrollment_email_verification.id
  order                = 30
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

# Step 5: MFA Setup — must run BEFORE the welcome screen. Welcome's HTML
# installs a JS submit-interceptor that redirects to / (correct terminal
# behavior for inactive users hitting the "reach out to a delegate" message)
# — if MFA fired after the welcome, active users would be bounced before
# ever setting up MFA. Order swapped 2026-05-25.
resource "authentik_flow_stage_binding" "manual_enrollment_mfa_setup_binding" {
  target = authentik_flow.manual_enrollment.uuid
  stage  = authentik_stage_authenticator_validate.mfa_validate_strict.id
  order  = 35
}

# Step 6: Welcome Message — only shown to users who finished MFA setup but
# are still is_active=false (the normal manual-enrollment outcome — accounts
# are inactive until a delegate activates). Gated by shared_inactive_user_gate
# (same policy the auth flows use); active users skip the stage entirely and
# proceed to user_login at 100.
# evaluate_on_plan=false + re_evaluate_policies=true ensures the gate runs
# AFTER user_write created the user, so pending_user is in context.
resource "authentik_flow_stage_binding" "manual_enrollment_welcome_binding" {
  target               = authentik_flow.manual_enrollment.uuid
  stage                = authentik_stage_prompt.manual_enrollment_welcome.id
  order                = 40
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

# Gate the welcome message on inactive-user — active users (re-entering the
# enrollment flow post-activation by an admin) skip it and hit user_login.
resource "authentik_policy_binding" "manual_enrollment_welcome_inactive_gate_binding" {
  target  = authentik_flow_stage_binding.manual_enrollment_welcome_binding.id
  policy  = authentik_policy_expression.shared_inactive_user_gate.id
  order   = 0
  enabled = true
  timeout = 30
}

# Step 6: Complete Login
resource "authentik_flow_stage_binding" "manual_enrollment_login_binding" {
  target = authentik_flow.manual_enrollment.uuid
  stage  = authentik_stage_user_login.manual_enrollment_user_login.id
  order  = 100
}

# POLICIES

# Copy email into username before account creation
resource "authentik_policy_expression" "manual_enrollment_set_username_from_email" {
  name              = "policy-manual-enrollment-set-username-from-email"
  execution_logging = true
  expression        = <<-EOT
    # Use email value as username so the user doesn't need to enter it twice
    try:
        prompt_data = request.context.get('prompt_data', {})
        user_email = prompt_data.get('email')
    except Exception as e:
        ak_logger.error(f"Error reading prompt data: {e}")
        user_email = None

    if user_email:
        if 'prompt_data' not in request.context:
            request.context['prompt_data'] = {}
        request.context['prompt_data']['username'] = user_email
        return True

    ak_message("Please provide a valid email address")
    return False
  EOT
}

resource "authentik_policy_binding" "manual_enrollment_set_username_from_email_binding" {
  target  = authentik_flow_stage_binding.manual_enrollment_user_write_binding.id
  policy  = authentik_policy_expression.manual_enrollment_set_username_from_email.id
  order   = 0
  enabled = true
  timeout = 30
}

# ALREADY-REGISTERED SHORT-CIRCUIT
#
# Catches users re-submitting manual-enrollment with an email that already has
# an account. Without this, user_write at order 20 fails with a generic
# uniqueness error and the user has no idea what happened. Bound at order 17
# (between AUP at 15 and user_write at 20); renders only when the
# email-uniqueness policy returns True. The rendered HTML installs a JS
# submit-interceptor that redirects to / so the user exits cleanly.

resource "authentik_stage_prompt_field" "manual_enrollment_already_registered_message" {
  name                   = "manual-enrollment-field-already-registered"
  field_key              = "already_registered_info"
  label                  = "Account Already Exists"
  type                   = "static"
  required               = false
  placeholder            = ""
  placeholder_expression = false
  initial_value = templatefile("${path.module}/../assets/already-registered-message.html.tpl", {
    organisation_name = var.organisation_name
  })
}

resource "authentik_stage_prompt" "manual_enrollment_already_registered" {
  name = "manual-enrollment-already-registered"
  fields = [
    authentik_stage_prompt_field.manual_enrollment_already_registered_message.id,
  ]
}

# True when an existing user already has the submitted email. Authentik's
# prompt-stage uniqueness semantics don't catch arbitrary email collisions —
# they surface as a generic backend error at user_write time — so we query
# User.objects directly. __iexact handles users re-enrolling with
# differently-cased email.
resource "authentik_policy_expression" "manual_enrollment_email_already_exists" {
  name              = "policy-manual-enrollment-email-already-exists"
  execution_logging = true
  expression        = <<-EOT
    prompt_data = request.context.get('prompt_data', {})
    email = (prompt_data.get('email') or '').strip().lower()
    if not email:
        return False
    try:
        from authentik.core.models import User
        return User.objects.filter(email__iexact=email).exists()
    except Exception as e:
        ak_logger.error(f"Error checking email existence: {e}")
        return False
  EOT
}

resource "authentik_flow_stage_binding" "manual_enrollment_already_registered_binding" {
  target               = authentik_flow.manual_enrollment.uuid
  stage                = authentik_stage_prompt.manual_enrollment_already_registered.id
  order                = 17
  policy_engine_mode   = "any"
  re_evaluate_policies = true
  evaluate_on_plan     = false
}

resource "authentik_policy_binding" "manual_enrollment_already_registered_policy" {
  target  = authentik_flow_stage_binding.manual_enrollment_already_registered_binding.id
  policy  = authentik_policy_expression.manual_enrollment_email_already_exists.id
  order   = 0
  enabled = true
  timeout = 30
}
