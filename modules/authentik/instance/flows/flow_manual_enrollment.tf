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

# STAGES

# Single prompt stage - All fields
resource "authentik_stage_prompt" "manual_enrollment_prompt_all" {
  name = "manual-enrollment-prompt-all"

  fields = [
    authentik_stage_prompt_field.manual_enrollment_name.id,
    authentik_stage_prompt_field.manual_enrollment_email.id,
    authentik_stage_prompt_field.manual_enrollment_password.id,
    authentik_stage_prompt_field.manual_enrollment_password_repeat.id,
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
  create_users_group       = var.union_member_group_id
  user_type                = "internal"
  user_creation_mode       = "always_create"
  user_path_template       = "users" # Store all users under "users" path
}

# Email Verification Stage
resource "authentik_stage_email" "manual_enrollment_email_verification" {
  name                     = "manual-enrollment-email-verification"
  use_global_settings      = false
  host                     = var.smtp_host
  port                     = var.smtp_port
  username                 = var.smtp_username
  password                 = var.smtp_password
  use_tls                  = false
  use_ssl                  = true
  timeout                  = 30
  from_address             = local.gateway_email
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

# Step 4.5: Welcome Message
# Note: evaluate_on_plan=false and re_evaluate_policies=true ensures the notification
# policy runs AFTER user_write has created the user, so the user is in context
resource "authentik_flow_stage_binding" "manual_enrollment_welcome_binding" {
  target               = authentik_flow.manual_enrollment.uuid
  stage                = authentik_stage_prompt.manual_enrollment_welcome.id
  order                = 35
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

# Step 5: MFA Setup
resource "authentik_flow_stage_binding" "manual_enrollment_mfa_setup_binding" {
  target = authentik_flow.manual_enrollment.uuid
  stage  = authentik_stage_authenticator_validate.mfa_validate_strict.id
  order  = 40
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
