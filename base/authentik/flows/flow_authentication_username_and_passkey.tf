# LOCAL AUTHENTICATION FLOW
# 
# Traditional local authentication flow:
# 1. Email identification
# 2. Password authentication  
# 3. MFA choice (if configured) or MFA setup (if none configured)
# 
# Social login users without MFA are blocked from this flow

# Local Authentication Flow
resource "authentik_flow" "authentication_flow_username_and_passkey" {
  name               = "${var.organisation_name} Gateway"
  title              = "${var.organisation_name} Gateway"
  slug               = "authentication-local-username-and-passkey"
  designation        = "authentication"
  authentication     = "none"
  layout             = "stacked"
  policy_engine_mode = "any"
  compatibility_mode = true
  denied_action      = "message_continue"
  background         = var.flow_background
}

# Flow Stage Bindings
resource "authentik_flow_stage_binding" "username_passkey_identification" {
  target = authentik_flow.authentication_flow_username_and_passkey.uuid
  stage  = authentik_stage_identification.username_passkey_identification.id
  order  = 10

  policy_engine_mode      = "all"
  invalid_response_action = "retry"
  re_evaluate_policies    = true
}

# Bind comprehensive authentication requirements check
resource "authentik_policy_binding" "complete_auth_requirements_binding" {
  target  = authentik_flow_stage_binding.username_passkey_identification.id
  policy  = authentik_policy_expression.enforce_complete_auth_requirements.id
  order   = 0
  enabled = true
  timeout = 30
}

# Password Authentication (always required for local login)
resource "authentik_flow_stage_binding" "username_passkey_password" {
  target = authentik_flow.authentication_flow_username_and_passkey.uuid
  stage  = authentik_stage_password.username_passkey_password.id
  order  = 20

  policy_engine_mode      = "any"
  invalid_response_action = "retry"
  re_evaluate_policies    = true
}

# SUPERSEDED POLICIES (2026-01-20)
# MFA Stage (Webauthn/TOTP/Email choice, or setup if none configured)
resource "authentik_flow_stage_binding" "username_passkey_mfa" {
  target = authentik_flow.authentication_flow_username_and_passkey.uuid
  stage  = authentik_stage_authenticator_validate.mfa_validate_strict.id
  order  = 30

  policy_engine_mode      = "any"
  invalid_response_action = "retry"
  re_evaluate_policies    = true
}

# Login Completion (final step for all authentication paths)
resource "authentik_flow_stage_binding" "username_passkey_login_completion" {
  target = authentik_flow.authentication_flow_username_and_passkey.uuid
  stage  = authentik_stage_user_login.shared_user_login.id
  order  = 40

  policy_engine_mode      = "any"
  invalid_response_action = "retry"
  re_evaluate_policies    = true
}

# AUTHENTICATION REQUIREMENTS POLICY
# Combined policy to enforce both password and MFA requirements
resource "authentik_policy_expression" "enforce_complete_auth_requirements" {
  name              = "policy-enforce-complete-auth-requirements"
  execution_logging = true
  expression        = <<-EOT
    # Comprehensive check for regular login requirements
    pending_user = request.context.get('pending_user', None)
    
    if not pending_user:
        return True  # Allow to proceed (will fail at appropriate stage)
    
    # Check password
    has_password = pending_user.has_usable_password()
    
    # Check MFA
    has_mfa = False
    try:
        from authentik.stages.authenticator_totp.models import TOTPDevice
        from authentik.stages.authenticator_webauthn.models import WebAuthnDevice
        from authentik.stages.email.models import EmailDevice
        
        has_mfa = (
            TOTPDevice.objects.filter(user=pending_user, confirmed=True).exists() or
            WebAuthnDevice.objects.filter(user=pending_user, confirmed=True).exists() or
            EmailDevice.objects.filter(user=pending_user, confirmed=True).exists()
        )
    except:
        pass
    
    # Check social connections
    has_social = False
    social_providers = []
    try:
        from authentik.sources.oauth.models import UserOAuthSourceConnection
        connections = UserOAuthSourceConnection.objects.filter(user=pending_user)
        has_social = connections.exists()
        if has_social:
            social_providers = [conn.source.name for conn in connections]
    except:
        pass
    
    # Decision logic
    if not has_password and has_social:
        providers_text = ', '.join(social_providers) if social_providers else "your social provider"
        ak_message(f"This is a social login account. Please use {providers_text} to sign in.")
        return False
    
    if not has_password:
        ak_message("No password is set for this account. Please use social login or contact support.")
        return False
    
    if not has_mfa and has_social:
        ak_message("MFA is required for password login. Use social login or set up MFA first.")
        return False
    
    if not has_mfa:
        ak_message("MFA setup is required. Please contact an administrator to set up MFA for your account.")
        return False
    
    # User has both password and MFA - allow regular login
    return True
  EOT
}
