# SOURCE AUTHENTICATION FLOW
# 
# Authentication flow for users logging in through social providers (Google/Apple).
# Existing users skip password and MFA entry and go directly to login.
# 
# Flow: Social Provider -> User Identification -> Direct Login (skip password/MFA)

# Source Authentication Flow for Social Logins
resource "authentik_flow" "source_authentication" {
  name               = "${var.organisation_name} Social Login"
  title              = "Welcome back to ${var.organisation_name}!"
  slug               = "source-authentication"
  designation        = "authentication"
  authentication     = "none"
  layout             = "stacked"
  policy_engine_mode = "all"
  compatibility_mode = true
  denied_action      = "message_continue"
  background         = var.flow_background
}

# FLOW STAGE BINDINGS

# Direct login binding - social users go straight to login (using shared stage)
resource "authentik_flow_stage_binding" "source_authentication_login" {
  target               = authentik_flow.source_authentication.uuid
  stage                = authentik_stage_user_login.shared_user_login.id
  order                = 10
  evaluate_on_plan     = true
  re_evaluate_policies = true
  policy_engine_mode   = "all"
}

# POLICIES

# Policy to ensure user exists and has a social connection
resource "authentik_policy_expression" "source_authentication_validation" {
  name              = "policy-source-authentication-validation"
  execution_logging = true
  expression        = <<-EOT
    # This policy validates that the user exists and has a valid social connection
    # The user comes from OAuth provider and should already be authenticated
    
    # Get the pending user from context
    pending_user = request.context.get('pending_user', None)
    
    if not pending_user:
        # Check if we have a user from the OAuth flow
        if 'user' in request.context:
            pending_user = request.context['user']
    
    if not pending_user:
        ak_message("No user found in authentication context")
        return False
    
    # Verify user has OAuth connections
    try:
        from authentik.sources.oauth.models import UserOAuthSourceConnection
        connections = UserOAuthSourceConnection.objects.filter(user=pending_user)
        
        if not connections.exists():
            ak_message("No social login connections found for this user")
            return False
        
        # Set the user in context for the login stage
        request.context['pending_user'] = pending_user
        
        # Log successful social authentication
        ak_logger.info(f"Social authentication successful for user: {pending_user.username}")
        
    except Exception as e:
        ak_logger.error(f"Error validating social connection: {str(e)}")
        return False
    
    return True
  EOT
}

# POLICY BINDINGS

# Original validation - DISABLED in favor of simpler approach
resource "authentik_policy_binding" "source_authentication_validation_binding" {
  target  = authentik_flow.source_authentication.uuid
  policy  = authentik_policy_expression.source_authentication_validation.id
  order   = 10
  enabled = false # DISABLED - using allow_social_linking instead
  timeout = 30
}

# Bind the new social linking policy
# DISABLED: Policy authentik_policy_expression.allow_social_linking not defined
# resource "authentik_policy_binding" "allow_social_linking_binding" {
#   target  = authentik_flow.source_authentication.uuid
#   policy  = authentik_policy_expression.allow_social_linking.id
#   order   = 0  # Primary check
#   enabled = true
#   timeout = 30
# }

# Inactive user check 
resource "authentik_policy_binding" "block_inactive_social_users_binding" {
  target  = authentik_flow.source_authentication.uuid
  policy  = authentik_policy_expression.block_inactive_social_users.id
  order   = 5     # Run after main check
  enabled = false # DISABLED - handled in allow_social_linking
  timeout = 30
}


# POLICY TO BLOCK INACTIVE USERS
# Prevents inactive users from logging in through source authentication
resource "authentik_policy_expression" "block_inactive_social_users" {
  name              = "policy-block-inactive-social-users"
  execution_logging = true
  expression        = <<-EOT
    # Block inactive users from logging in
    pending_user = request.context.get('pending_user', None)
    
    if not pending_user:
        if 'user' in request.context:
            pending_user = request.context['user']
    
    if pending_user:
        # Check if user is inactive
        if not pending_user.is_active:
            ak_message("Your account is pending activation. Please wait for a delegate to approve your account.")
            return False
        
        # Check if user is in pending-activation group
        user_groups = [group.name for group in pending_user.ak_groups.all()]
        if 'pending-activation' in user_groups:
            ak_message("Your account is awaiting delegate approval. You will receive an email once activated.")
            return False
    
    return True
  EOT
}
