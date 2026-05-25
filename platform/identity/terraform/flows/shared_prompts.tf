# SHARED PROMPT FIELDS
# Reusable prompt fields that can be shared across multiple flows.

# Shared Welcome Message Field
# This field displays a success message after enrollment (manual or social)
# instructing the user to contact a delegate for activation.
# Both the default "Continue" button and custom "Return to Home" button redirect to home page.
resource "authentik_stage_prompt_field" "shared_welcome_message" {
  name                   = "shared-prompt-field-welcome-message"
  field_key              = "welcome_info"
  label                  = "Welcome!"
  type                   = "static"
  required               = false
  placeholder            = ""
  placeholder_expression = false
  initial_value = templatefile("${path.module}/../assets/enrollment-welcome-message.html.tpl", {
    organisation_name = var.organisation_name
  })
}

# =============================================================================
# ACCEPTABLE USE POLICY (AUP)
# =============================================================================
# Shared AUP stage used during all enrollment flows (manual, social, invitation)

# AUP Text Field - Displays the policy
resource "authentik_stage_prompt_field" "shared_aup_text" {
  name                   = "shared-prompt-field-aup-text"
  field_key              = "aup_text"
  label                  = "Acceptable Use Policy"
  type                   = "static"
  required               = false
  placeholder            = ""
  placeholder_expression = false
  initial_value = templatefile("${path.module}/../assets/acceptable-use-policy.html", {
    domain = var.domain
  })
  order = 0
}

# AUP Acceptance Checkbox
resource "authentik_stage_prompt_field" "shared_aup_checkbox" {
  name                   = "shared-prompt-field-aup-checkbox"
  field_key              = "aup_accepted"
  label                  = "I Accept the Acceptable Use Policy"
  type                   = "checkbox"
  required               = true
  placeholder            = ""
  placeholder_expression = false
  order                  = 1
}

# AUP Prompt Stage - Combines text and checkbox
resource "authentik_stage_prompt" "shared_aup" {
  name = "shared-prompt-aup"
  fields = [
    authentik_stage_prompt_field.shared_aup_text.id,
    authentik_stage_prompt_field.shared_aup_checkbox.id,
  ]
  validation_policies = [
    authentik_policy_expression.shared_aup_validation.id,
  ]
}

# AUP Validation Policy - Ensures checkbox is checked
resource "authentik_policy_expression" "shared_aup_validation" {
  name              = "policy-shared-aup-validation"
  execution_logging = true
  expression        = <<-EOT
    # Validate that user has accepted the Acceptable Use Policy
    prompt_data = request.context.get('prompt_data', {})
    aup_accepted = prompt_data.get('aup_accepted', False)

    if not aup_accepted:
        ak_message("You must accept the Acceptable Use Policy to continue.")
        return False

    return True
  EOT
}

# =============================================================================
# INACTIVE-USER MESSAGE
# =============================================================================
# Shown on auth flows when a user successfully passes password + MFA but is
# still flagged is_active = False. The user gets a full-page "reach out to a
# delegate" message instead of Authentik's default silent error. Bound on
# both auth flows (local password+MFA + source/social) with a gating policy
# that fires only when pending_user.is_active is False.

resource "authentik_stage_prompt_field" "shared_inactive_user_message" {
  name                   = "shared-prompt-field-inactive-user-message"
  field_key              = "inactive_user_info"
  label                  = "Account inactive"
  type                   = "static"
  required               = false
  placeholder            = ""
  placeholder_expression = false
  initial_value = templatefile("${path.module}/../assets/inactive-user-message.html.tpl", {
    organisation_name = var.organisation_name
  })
}

resource "authentik_stage_prompt" "shared_inactive_user" {
  name = "shared-prompt-inactive-user"
  fields = [
    authentik_stage_prompt_field.shared_inactive_user_message.id,
  ]
}

# Gating policy — return True (show stage) only when pending_user is inactive.
resource "authentik_policy_expression" "shared_inactive_user_gate" {
  name              = "policy-shared-inactive-user-gate"
  execution_logging = true
  expression        = <<-EOT
    # Show the inactive-user message stage only when the user being logged
    # in is flagged is_active = False. Returning False causes the binding
    # to skip the stage entirely, so active users never see this prompt.
    pending_user = request.context.get('pending_user', None)
    if not pending_user:
        return False
    return not pending_user.is_active
  EOT
}
