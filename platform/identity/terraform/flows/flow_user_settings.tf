# USER SETTINGS FLOW
#
# Clones Authentik's built-in default-user-settings-flow minus the username
# field — same prompt shape (name, email, locale, member_id) the default ships,
# just without the username editor (it confuses users now that username = email
# always, per the source/manual enrollment invariant).
#
# Password change + delete account are SEPARATE flows triggered by buttons
# in Authentik's user-settings UI — wired by brand.tf's flow_recovery and
# flow_unenrollment settings. Not in this flow.
#
# Contract: bundle output `authentik.flows.user_settings_flow` still a
# UUID string. The UUID itself changes (replacing the built-in default).
# Consumers pinning the old default flow ID outside `var.base.authentik`
# need to bump.

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

# PROMPT FIELDS — mirrors Authentik's default user-settings flow minus username.

resource "authentik_stage_prompt_field" "user_settings_name" {
  name                     = "user-settings-field-name"
  field_key                = "name"
  label                    = "Name"
  type                     = "text"
  required                 = true
  placeholder              = "Name"
  placeholder_expression   = false
  initial_value            = "return request.user.name"
  initial_value_expression = true
  order                    = 0
}

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

resource "authentik_stage_prompt_field" "user_settings_locale" {
  name                     = "user-settings-field-locale"
  field_key                = "attributes.settings.locale"
  label                    = "Locale"
  type                     = "text"
  required                 = false
  placeholder              = "en"
  placeholder_expression   = false
  initial_value            = "return request.user.attributes.get('settings', {}).get('locale', '')"
  initial_value_expression = true
  order                    = 20
}

# Optional on edit so users can clear it. Stored as user.attributes.member_id.
resource "authentik_stage_prompt_field" "user_settings_member_id" {
  name                     = "user-settings-field-member-id"
  field_key                = "attributes.member_id"
  label                    = "Member ID"
  type                     = "text"
  required                 = false
  placeholder              = ""
  placeholder_expression   = false
  initial_value            = "return request.user.attributes.get('member_id', '')"
  initial_value_expression = true
  order                    = 30
}

resource "authentik_stage_prompt" "user_settings_prompt" {
  name = "user-settings-prompt"
  fields = [
    authentik_stage_prompt_field.user_settings_name.id,
    authentik_stage_prompt_field.user_settings_email.id,
    authentik_stage_prompt_field.user_settings_locale.id,
    authentik_stage_prompt_field.user_settings_member_id.id,
  ]

  validation_policies = [
    authentik_policy_expression.shared_member_id_normalize.id,
    authentik_policy_expression.shared_member_id_unique.id,
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
