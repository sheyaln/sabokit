# INVITATION FLOW
#
# Flow for inviting new users to join the organization.
# The flow encourages users to sign up with Google or Apple for a seamless experience,
# while providing manual email/password registration as a fallback option.
#
# Flow paths:
# 1. Social Login (encouraged): User clicks Google/Apple -> OAuth flow -> source_enrollment_flow
# 2. Manual Registration: User fills out email/password form -> account created
#

# =============================================================================
# INVITATION FLOW
# =============================================================================

resource "authentik_flow" "user_invitation_flow" {
  name               = "User Invitation Flow"
  title              = "Join ${var.organisation_name}"
  slug               = "user-invitation"
  designation        = "enrollment"
  authentication     = "require_unauthenticated"
  layout             = "stacked"
  denied_action      = "message"
  policy_engine_mode = "all"
  background         = var.flow_background
}

# =============================================================================
# STAGES
# =============================================================================

# Invitation Stage - Validates the invitation token from ?itoken= parameter
resource "authentik_stage_invitation" "invitation_validation" {
  name                             = "invitation-stage-validation"
  continue_flow_without_invitation = false # Require valid invitation token
}

# Welcome Stage - Shows social login options prominently with manual fallback
resource "authentik_stage_prompt" "invitation_welcome" {
  name = "invitation-prompt-welcome"
  fields = [
    authentik_stage_prompt_field.invitation_welcome_message.id,
  ]
  validation_policies = []
}

# Manual Registration Prompt - For users who choose email/password
resource "authentik_stage_prompt" "invitation_manual_registration" {
  name = "invitation-prompt-manual-registration"
  fields = [
    authentik_stage_prompt_field.invitation_name.id,
    authentik_stage_prompt_field.invitation_email.id,
    authentik_stage_prompt_field.invitation_password.id,
    authentik_stage_prompt_field.invitation_password_repeat.id,
  ]
  validation_policies = [
    authentik_policy_expression.invitation_password_match.id,
  ]
}

# User Write Stage - Creates the user account
resource "authentik_stage_user_write" "invitation_user_write" {
  name                     = "invitation-user-write"
  create_users_as_inactive = false # Invited users are active immediately
  create_users_group       = var.union_member_group_id
  user_type                = "internal"
  user_creation_mode       = "always_create"
  user_path_template       = "users" # Store all users under "users" path
}

# Email Verification Stage
resource "authentik_stage_email" "invitation_email_verification" {
  name                = "invitation-email-verification"
  use_global_settings = false

  # SMTP Configuration
  host         = var.smtp_host
  port         = var.smtp_port
  username     = var.smtp_username
  password     = var.smtp_password
  use_tls      = false
  use_ssl      = true
  timeout      = 30
  from_address = local.gateway_email

  subject                  = "Verify your email - ${var.organisation_name}"
  activate_user_on_success = true
  token_expiry             = "hours=72"
}

# =============================================================================
# PROMPT FIELDS
# =============================================================================

# Welcome message with social login encouragement
resource "authentik_stage_prompt_field" "invitation_welcome_message" {
  name                   = "invitation-field-welcome-message"
  field_key              = "invitation_welcome"
  label                  = "Welcome!"
  type                   = "static"
  required               = false
  placeholder            = ""
  placeholder_expression = false
  initial_value = templatefile("${path.module}/../assets/invitation-welcome.html.tpl", {
    organisation_name = var.organisation_name
  })
  order = 0
}

# Name field for manual registration
resource "authentik_stage_prompt_field" "invitation_name" {
  name                   = "invitation-field-name"
  field_key              = "name"
  label                  = "Your Name"
  type                   = "text"
  required               = true
  placeholder            = "Enter your name"
  placeholder_expression = false
  order                  = 1
}

# Email field for manual registration
resource "authentik_stage_prompt_field" "invitation_email" {
  name                   = "invitation-field-email"
  field_key              = "email"
  label                  = "Email Address"
  type                   = "email"
  required               = true
  placeholder            = "you@example.com"
  placeholder_expression = false
  order                  = 2
}

# Password field for manual registration
resource "authentik_stage_prompt_field" "invitation_password" {
  name                   = "invitation-field-password"
  field_key              = "password"
  label                  = "Password"
  type                   = "password"
  required               = true
  placeholder            = "Choose a strong password"
  placeholder_expression = false
  order                  = 3
}

# Password repeat field for manual registration
resource "authentik_stage_prompt_field" "invitation_password_repeat" {
  name                   = "invitation-field-password-repeat"
  field_key              = "password_repeat"
  label                  = "Confirm Password"
  type                   = "password"
  required               = true
  placeholder            = "Repeat your password"
  placeholder_expression = false
  order                  = 4
}

# =============================================================================
# FLOW STAGE BINDINGS
# =============================================================================

# Stage 0: Validate invitation token (must be first)
resource "authentik_flow_stage_binding" "invitation_validation_binding" {
  target               = authentik_flow.user_invitation_flow.uuid
  stage                = authentik_stage_invitation.invitation_validation.id
  order                = 0
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# Stage 1: Welcome prompt with social login options
resource "authentik_flow_stage_binding" "invitation_welcome_binding" {
  target               = authentik_flow.user_invitation_flow.uuid
  stage                = authentik_stage_prompt.invitation_welcome.id
  order                = 10
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# Stage 2: Manual registration form (for users who clicked "Continue")
resource "authentik_flow_stage_binding" "invitation_manual_registration_binding" {
  target               = authentik_flow.user_invitation_flow.uuid
  stage                = authentik_stage_prompt.invitation_manual_registration.id
  order                = 20
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# Stage 3: Acceptable Use Policy
resource "authentik_flow_stage_binding" "invitation_aup_binding" {
  target               = authentik_flow.user_invitation_flow.uuid
  stage                = authentik_stage_prompt.shared_aup.id
  order                = 25
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# Stage 4: Create user account
resource "authentik_flow_stage_binding" "invitation_write_binding" {
  target               = authentik_flow.user_invitation_flow.uuid
  stage                = authentik_stage_user_write.invitation_user_write.id
  order                = 30
  evaluate_on_plan     = true
  re_evaluate_policies = true
}

# Stage 5: Email verification
resource "authentik_flow_stage_binding" "invitation_email_verification_binding" {
  target               = authentik_flow.user_invitation_flow.uuid
  stage                = authentik_stage_email.invitation_email_verification.id
  order                = 40
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# Stage 6: Complete login
resource "authentik_flow_stage_binding" "invitation_login_binding" {
  target               = authentik_flow.user_invitation_flow.uuid
  stage                = authentik_stage_user_login.shared_user_login.id
  order                = 50
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# =============================================================================
# POLICIES
# =============================================================================

# Policy to copy email into username before account creation
resource "authentik_policy_expression" "invitation_set_username_from_email" {
  name              = "policy-invitation-set-username-from-email"
  execution_logging = true
  expression        = <<-EOT
    # Use email value as username
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

# Policy to validate password match
resource "authentik_policy_expression" "invitation_password_match" {
  name              = "policy-invitation-password-match"
  execution_logging = true
  expression        = <<-EOT
    # Validate that passwords match
    prompt_data = request.context.get('prompt_data', {})
    password = prompt_data.get('password', '')
    password_repeat = prompt_data.get('password_repeat', '')
    
    if password != password_repeat:
        ak_message("Passwords do not match")
        return False
    
    if len(password) < 8:
        ak_message("Password must be at least 8 characters")
        return False
    
    return True
  EOT
}

# =============================================================================
# POLICY BINDINGS
# =============================================================================

# Bind username-from-email policy to user write stage
resource "authentik_policy_binding" "invitation_set_username_binding" {
  target  = authentik_flow_stage_binding.invitation_write_binding.id
  policy  = authentik_policy_expression.invitation_set_username_from_email.id
  order   = 0
  enabled = true
  timeout = 30
}

# =============================================================================
# INVITATION EMAIL STAGE (for sending invitations)
# =============================================================================

# This stage is used to SEND invitation emails (separate from the flow above)
resource "authentik_stage_email" "send_user_invitation" {
  name                = "email-stage-send-invitation"
  use_global_settings = false

  # SMTP Configuration
  host         = var.smtp_host
  port         = var.smtp_port
  username     = var.smtp_username
  password     = var.smtp_password
  use_tls      = false
  use_ssl      = true
  timeout      = 30
  from_address = local.gateway_email

  subject                  = "You're invited to join ${var.organisation_name}!"
  activate_user_on_success = false
  token_expiry             = "hours=168" # 7 days
}
