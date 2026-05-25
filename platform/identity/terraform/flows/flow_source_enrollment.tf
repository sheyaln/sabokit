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
  title              = "Welcome to ${var.organisation_name}"
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
  create_users_as_inactive = true                # Users created via social login are inactive until activated by a delegate
  create_users_group       = var.member_group_id # New users land in the standard-member group
  user_path_template       = "users"             # Store all users under "users" path regardless of OAuth source
}

# Welcome prompt stage (optional - shows welcome message)
resource "authentik_stage_prompt" "source_enrollment_welcome" {
  name = "source-enrollment-welcome"
  fields = [
    authentik_stage_prompt_field.shared_welcome_message.id,
  ]
}

# Profile prompt — given_name (required) + member_id (optional, label override).
# Runs after AUP, before user_write, so the policy-source-enrollment-user-setup
# expression can pull both values out of prompt_data and into the right places
# (user.name, user.attributes['member_id']). Attribute key for the second field
# stays "member_id" across consumers; only the on-screen label is per-org.
resource "authentik_stage_prompt_field" "source_enrollment_given_name" {
  name                   = "source-enrollment-field-given-name"
  field_key              = "given_name"
  label                  = "First Name"
  type                   = "text"
  required               = true
  placeholder            = "Your first name"
  placeholder_expression = false
  order                  = 1
}

resource "authentik_stage_prompt_field" "source_enrollment_member_id" {
  name                   = "source-enrollment-field-member-id"
  field_key              = "member_id"
  label                  = var.member_id_label
  type                   = "text"
  required               = false
  placeholder            = ""
  placeholder_expression = false
  order                  = 2
}

resource "authentik_stage_prompt" "source_enrollment_profile" {
  name = "source-enrollment-profile"
  fields = [
    authentik_stage_prompt_field.source_enrollment_given_name.id,
    authentik_stage_prompt_field.source_enrollment_member_id.id,
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

# Stage 1.5: Profile prompt — given_name (required) + member_id (optional).
# Sits between AUP and user_write so prompt_data carries both values into the
# user-setup policy expression bound to the write stage.
resource "authentik_flow_stage_binding" "source_enrollment_profile_binding" {
  target               = authentik_flow.source_enrollment.uuid
  stage                = authentik_stage_prompt.source_enrollment_profile.id
  order                = 7
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

# Policy to set user data from OAuth provider + the profile prompt.
# Username = email unconditionally (matches the manual + user-settings flows).
# user.name comes from the prompt's given_name (required); we still concat
# OAuth family_name if the provider gave one. member_id from the prompt
# (optional) goes through prompt_data so user_write lands it in
# user.attributes['member_id'].
resource "authentik_policy_expression" "source_enrollment_user_setup" {
  name              = "policy-source-enrollment-user-setup"
  execution_logging = true
  expression        = <<-EOT
    # Pull email from OAuth context (Google/Apple both supply it).
    user_email = ""
    if 'oauth_userinfo' in context and 'email' in context['oauth_userinfo']:
        user_email = context['oauth_userinfo']['email']
    elif 'email' in context:
        user_email = context['email']

    if not user_email:
        ak_message("Unable to extract email from social provider")
        return False

    # Profile prompt data (given_name required, member_id optional).
    prompt_data = request.context.get('prompt_data', {}) or {}
    given_name = (prompt_data.get('given_name') or '').strip()
    member_id  = (prompt_data.get('member_id') or '').strip()

    # OAuth family_name is appended to the prompt's given_name when present.
    family_name = ''
    if 'oauth_userinfo' in context:
        family_name = (context['oauth_userinfo'].get('family_name') or '').strip()

    # Defensive: prompt is required, so given_name should always be set.
    # If somehow empty, fall back to OAuth-provided name fields so we never
    # write an empty user.name.
    if not given_name and 'oauth_userinfo' in context:
        given_name = (context['oauth_userinfo'].get('given_name') or
                      context['oauth_userinfo'].get('name') or '').strip()

    full_name = (given_name + ' ' + family_name).strip() if family_name else given_name

    if 'prompt_data' not in request.context:
        request.context['prompt_data'] = {}

    # Username locked to email.
    request.context['prompt_data']['username'] = user_email
    request.context['prompt_data']['email']    = user_email
    request.context['prompt_data']['name']     = full_name

    # member_id is optional — only set when supplied. user_write writes
    # non-User-model prompt_data keys into user.attributes, so this lands
    # in user.attributes['member_id'].
    if member_id:
        request.context['prompt_data']['member_id'] = member_id
    elif 'member_id' in request.context['prompt_data']:
        # Strip empty value so user_write doesn't store "".
        del request.context['prompt_data']['member_id']

    # Mark user as social-only (no password).
    request.context['is_social_only'] = True

    ak_logger.info(f"Setting up social user: {user_email}")
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
