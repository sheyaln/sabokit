# MFA RESET EMAIL STAGE
# Used for sending MFA device reset confirmation emails
resource "authentik_stage_email" "mfa_reset" {
  name                = "email-stage-mfa-reset"
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

  # MFA reset specific settings
  subject = "MFA Device Reset Confirmation - ${var.organisation_name}"
  # template               = "email/setup.html"  # Will use system default if not specified
  activate_user_on_success = false
  token_expiry             = "minutes=30" # 30 minutes
}

# MFA RESET FLOW
# Complete flow for MFA device reset
resource "authentik_flow" "mfa_reset_flow" {
  name               = "MFA Device Reset Flow"
  title              = "Reset your MFA devices"
  slug               = "mfa-reset"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  layout             = "stacked"
  denied_action      = "message"
  policy_engine_mode = "all"
}

# Prompt stage for MFA reset confirmation
resource "authentik_stage_prompt" "mfa_reset_confirmation" {
  name = "mfa-reset-confirmation"
  fields = [
    authentik_stage_prompt_field.mfa_reset_confirm.id,
  ]
}

# User delete stage for removing MFA devices
resource "authentik_stage_user_delete" "mfa_device_delete" {
  name = "mfa-device-delete"
}

# MFA RESET PROMPT FIELDS

resource "authentik_stage_prompt_field" "mfa_reset_confirm" {
  name                   = "prompt-field-mfa-reset-confirm"
  field_key              = "confirm_reset"
  label                  = "Type 'RESET' to confirm MFA device removal"
  type                   = "text"
  required               = true
  placeholder            = "Type RESET to confirm"
  placeholder_expression = false
}

# MFA RESET FLOW STAGE BINDINGS

resource "authentik_flow_stage_binding" "mfa_reset_email_binding" {
  target               = authentik_flow.mfa_reset_flow.uuid
  stage                = authentik_stage_email.mfa_reset.id
  order                = 10
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

resource "authentik_flow_stage_binding" "mfa_reset_confirmation_binding" {
  target               = authentik_flow.mfa_reset_flow.uuid
  stage                = authentik_stage_prompt.mfa_reset_confirmation.id
  order                = 20
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

resource "authentik_flow_stage_binding" "mfa_device_delete_binding" {
  target               = authentik_flow.mfa_reset_flow.uuid
  stage                = authentik_stage_user_delete.mfa_device_delete.id
  order                = 30
  evaluate_on_plan     = true
  re_evaluate_policies = false
}

# MFA RESET POLICIES

# Policy to validate MFA reset confirmation
resource "authentik_policy_expression" "mfa_reset_validation" {
  name              = "policy-mfa-reset-validation"
  execution_logging = true
  expression        = <<-EOT
    # Validate MFA reset confirmation
    confirmation = request.context.get('prompt_data', {}).get('confirm_reset', '')
    
    if confirmation.upper() != 'RESET':
        ak_message("Please type RESET to confirm MFA device removal")
        return False
    
    return True
  EOT
}

# Bind MFA reset validation to MFA reset confirmation
resource "authentik_policy_binding" "mfa_reset_validation_binding" {
  target  = authentik_flow_stage_binding.mfa_reset_confirmation_binding.id
  policy  = authentik_policy_expression.mfa_reset_validation.id
  order   = 0
  enabled = true
  timeout = 30
}
