# USER SETTINGS FLOW (custom)
#
# Replaces Authentik's built-in "default-user-settings-flow" with a custom
# flow that:
#   - hides the username field from the edit-info screen (email only)
#   - on email update, sets user.username = user.email so the two stay
#     in lockstep (matches the manual-enrollment + source-enrollment
#     invariant: username is always the email)
#
# Contract: the bundle output `authentik.flows.user_settings_flow` keeps
# its shape (UUID string). The UUID itself changes — consumers that
# pinned the old default flow ID anywhere outside `var.base.authentik`
# need to bump their reference.

resource "authentik_flow" "user_settings" {
  name               = "${var.organisation_name} User Settings"
  title              = "Update your details"
  slug               = "user-settings"
  designation        = "stage_configuration"
  authentication     = "require_authenticated"
  layout             = "stacked"
  policy_engine_mode = "any"
  compatibility_mode = true
  denied_action      = "message_continue"
  background         = var.flow_background
}

# PROMPT FIELDS — email only. Username is intentionally absent.
# Adding name/locale/etc. fields here later is additive.

resource "authentik_stage_prompt_field" "user_settings_email" {
  name                     = "user-settings-field-email"
  field_key                = "email"
  label                    = "Email"
  type                     = "email"
  required                 = true
  placeholder              = "user@example.org"
  placeholder_expression   = false
  initial_value            = "return request.user.email"
  initial_value_expression = true
  order                    = 10
}

resource "authentik_stage_prompt" "user_settings_prompt" {
  name = "user-settings-prompt"
  fields = [
    authentik_stage_prompt_field.user_settings_email.id,
  ]
}

# USER WRITE — persists prompt_data back onto the current user.
resource "authentik_stage_user_write" "user_settings_write" {
  name               = "user-settings-user-write"
  user_creation_mode = "never_create"
  user_type          = "internal"
  user_path_template = "users"
}

# FLOW STAGE BINDINGS

resource "authentik_flow_stage_binding" "user_settings_prompt_binding" {
  target               = authentik_flow.user_settings.uuid
  stage                = authentik_stage_prompt.user_settings_prompt.id
  order                = 10
  evaluate_on_plan     = true
  re_evaluate_policies = true
}

resource "authentik_flow_stage_binding" "user_settings_write_binding" {
  target               = authentik_flow.user_settings.uuid
  stage                = authentik_stage_user_write.user_settings_write.id
  order                = 20
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

# POLICY — copy email into username before user_write commits.
# Same shape as manual-enrollment's set-username-from-email policy; runs
# pre-write so user_write commits both fields atomically.
resource "authentik_policy_expression" "user_settings_sync_username_to_email" {
  name              = "policy-user-settings-sync-username-to-email"
  execution_logging = true
  expression        = <<-EOT
    # Keep username locked to email on every edit-info submission.
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

resource "authentik_policy_binding" "user_settings_sync_username_to_email_binding" {
  target  = authentik_flow_stage_binding.user_settings_write_binding.id
  policy  = authentik_policy_expression.user_settings_sync_username_to_email.id
  order   = 0
  enabled = true
  timeout = 30
}
