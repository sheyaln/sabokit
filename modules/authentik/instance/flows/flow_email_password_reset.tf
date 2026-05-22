# PASSWORD RESET FLOW

# Default recovery flow
resource "authentik_flow" "password_reset_flow" {
  name               = "Password Reset Flow"
  title              = "Reset your password"
  slug               = "password-reset"
  designation        = "recovery"
  authentication     = "require_unauthenticated"
  layout             = "stacked"
  denied_action      = "message"
  policy_engine_mode = "all"
}

# PROMPT FIELDS

resource "authentik_stage_prompt_field" "password_reset" {
  name                   = "password-reset-field-password"
  field_key              = "password"
  label                  = "Password"
  type                   = "password"
  required               = true
  placeholder            = "Password"
  order                  = 0
  placeholder_expression = false
}

resource "authentik_stage_prompt_field" "password_repeat_reset" {
  name                   = "password-reset-field-password-repeat"
  field_key              = "password_repeat"
  label                  = "Password (repeat)"
  type                   = "password"
  required               = true
  placeholder            = "Password (repeat)"
  order                  = 1
  placeholder_expression = false
}

# STAGES

# Skip if restored policy
resource "authentik_policy_expression" "password_reset_skip_if_restored" {
  name              = "password-reset-skip-if-restored"
  execution_logging = true
  expression        = <<-EOT
    return bool(request.context.get('is_restored', True))
  EOT
}

# Email stage with custom branding but following blueprint structure
resource "authentik_stage_email" "password_reset" {
  name                = "password-reset-email"
  use_global_settings = false # We want to use custom SMTP settings

  # Custom SMTP Configuration (maintaining your branding)
  host         = var.smtp_host
  port         = var.smtp_port
  username     = var.smtp_username
  password     = var.smtp_password
  use_tls      = false
  use_ssl      = true
  timeout      = 10
  from_address = local.gateway_email

  # Recovery settings from blueprint
  token_expiry             = "minutes=30"
  subject                  = "Password Reset Request - ${var.organisation_name}" # Your custom subject
  template                 = "email/password_reset.html"
  activate_user_on_success = true
}

# User write stage
resource "authentik_stage_user_write" "password_reset_write" {
  name               = "password-reset-user-write"
  user_creation_mode = "never_create"
}

# Identification stage
resource "authentik_stage_identification" "password_reset_identification" {
  name                      = "password-reset-identification"
  user_fields               = ["email", "username"]
  case_insensitive_matching = true
  show_matched_user         = false
  pretend_user_exists       = true
}

# User login stage
resource "authentik_stage_user_login" "password_reset_login" {
  name = "password-reset-user-login"
}

# Password prompt stage
resource "authentik_stage_prompt" "password_reset_prompt" {
  name = "Change your password"
  fields = [
    authentik_stage_prompt_field.password_reset.id,
    authentik_stage_prompt_field.password_repeat_reset.id,
  ]
  validation_policies = []
}

# FLOW STAGE BINDINGS (Exact order from blueprint)

# Identification stage binding (order 10)
resource "authentik_flow_stage_binding" "password_reset_identification_binding" {
  target                  = authentik_flow.password_reset_flow.uuid
  stage                   = authentik_stage_identification.password_reset_identification.id
  order                   = 10
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

# Email stage binding (order 20)
resource "authentik_flow_stage_binding" "password_reset_email_binding" {
  target                  = authentik_flow.password_reset_flow.uuid
  stage                   = authentik_stage_email.password_reset.id
  order                   = 20
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

# Password prompt stage binding (order 30)
resource "authentik_flow_stage_binding" "password_reset_prompt_binding" {
  target                  = authentik_flow.password_reset_flow.uuid
  stage                   = authentik_stage_prompt.password_reset_prompt.id
  order                   = 30
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

# User write stage binding (order 40)
resource "authentik_flow_stage_binding" "password_reset_write_binding" {
  target                  = authentik_flow.password_reset_flow.uuid
  stage                   = authentik_stage_user_write.password_reset_write.id
  order                   = 40
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

# User login stage binding (order 100)
resource "authentik_flow_stage_binding" "password_reset_login_binding" {
  target                  = authentik_flow.password_reset_flow.uuid
  stage                   = authentik_stage_user_login.password_reset_login.id
  order                   = 100
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

# POLICY BINDINGS (Exact structure from blueprint)

# Bind skip-if-restored policy to identification stage
resource "authentik_policy_binding" "password_reset_skip_identification_binding" {
  target  = authentik_flow_stage_binding.password_reset_identification_binding.id
  policy  = authentik_policy_expression.password_reset_skip_if_restored.id
  order   = 0
  enabled = true
  timeout = 30
  negate  = false
}
