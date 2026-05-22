# SOURCE ENROLLMENT FLOW (PASSWORDLESS)
# 
# Enrollment flow for new users via social login providers (Google/Apple).
# Users are NOT prompted to set up password or MFA.
# They can only authenticate via their social provider.
# 
# Flow: Social Login -> Auto User Creation -> Direct Login

# Source Enrollment Flow (Passwordless)
resource "authentik_flow" "source_enrollment" {
  name               = "${var.organisation_name} Social Enrollment"
  title              = "Welcome to ${var.organisation_name}, Fellow Worker!"
  slug               = "source-enrollment"
  designation        = "enrollment"
  authentication     = "none"
  layout             = "stacked"
  policy_engine_mode = "all"
  compatibility_mode = true
  denied_action      = "message_continue"
  background         = var.flow_background
}

# ENROLLMENT STAGES

# User Write Stage - Creates the user account
resource "authentik_stage_user_write" "source_enrollment_write" {
  name                     = "source-enrollment-user-write"
  user_type                = "internal"
  user_creation_mode       = "always_create"
  create_users_as_inactive = true                      # Users created via social login are inactive until activated by a delegate
  create_users_group       = var.union_member_group_id # New users start in union-member group
  user_path_template       = "users"                   # Store all users under "users" path regardless of OAuth source
}

# Welcome prompt stage (optional - shows welcome message)
resource "authentik_stage_prompt" "source_enrollment_welcome" {
  name = "source-enrollment-welcome"
  fields = [
    authentik_stage_prompt_field.shared_welcome_message.id,
  ]
}

# FLOW STAGE BINDINGS
# Stage 1: Acceptable Use Policy
resource "authentik_flow_stage_binding" "source_enrollment_aup_binding" {
  target               = authentik_flow.source_enrollment.uuid
  stage                = authentik_stage_prompt.shared_aup.id
  order                = 5
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# Stage 2: User Write (Create Account)
resource "authentik_flow_stage_binding" "source_enrollment_write_binding" {
  target               = authentik_flow.source_enrollment.uuid
  stage                = authentik_stage_user_write.source_enrollment_write.id
  order                = 10
  evaluate_on_plan     = true
  re_evaluate_policies = true
}

# Stage 3: Welcome Message
# Note: evaluate_on_plan=false and re_evaluate_policies=true ensures the notification
# policy runs AFTER user_write has created the user, so the user is in context
resource "authentik_flow_stage_binding" "source_enrollment_welcome_binding" {
  target               = authentik_flow.source_enrollment.uuid
  stage                = authentik_stage_prompt.source_enrollment_welcome.id
  order                = 20
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

# Stage 4: User Login (using shared stage)
resource "authentik_flow_stage_binding" "source_enrollment_login_binding" {
  target               = authentik_flow.source_enrollment.uuid
  stage                = authentik_stage_user_login.shared_user_login.id # CONSOLIDATED: was source_enrollment_login
  order                = 30
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# POLICIES

# Policy to set user data from OAuth provider
resource "authentik_policy_expression" "source_enrollment_user_setup" {
  name              = "policy-source-enrollment-user-setup"
  execution_logging = true
  expression        = <<-EOT
    # Extract user data from OAuth provider and set it up
    user_email = ""
    user_name = ""
    full_name = ""
    
    # Extract email and name from OAuth context
    if 'oauth_userinfo' in context and 'email' in context['oauth_userinfo']:
        user_email = context['oauth_userinfo']['email']
        
        # Try to get name
        if 'name' in context['oauth_userinfo']:
            full_name = context['oauth_userinfo']['name']
        elif 'given_name' in context['oauth_userinfo']:
            full_name = context['oauth_userinfo'].get('given_name', '')
            if 'family_name' in context['oauth_userinfo']:
                full_name += ' ' + context['oauth_userinfo']['family_name']
    elif 'email' in context:
        user_email = context['email']
    
    # Set username from email
    if user_email:
        user_name = user_email.split('@')[0]
        
        # Store user data in context
        if 'prompt_data' not in request.context:
            request.context['prompt_data'] = {}
        
        request.context['prompt_data']['username'] = user_email  # Use email as username
        request.context['prompt_data']['email'] = user_email
        request.context['prompt_data']['name'] = full_name
        
        # Mark user as social-only (no password)
        request.context['is_social_only'] = True
        
        ak_logger.info(f"Setting up social user: {user_email}")
    else:
        ak_message("Unable to extract email from social provider")
        return False
    
    return True
  EOT
}

# POLICY BINDINGS

# Bind user setup policy to user write stage
resource "authentik_policy_binding" "source_enrollment_user_setup_binding" {
  target  = authentik_flow_stage_binding.source_enrollment_write_binding.id
  policy  = authentik_policy_expression.source_enrollment_user_setup.id
  order   = 0
  enabled = true
  timeout = 30
}
