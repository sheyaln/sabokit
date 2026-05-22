# Common Prompt Fields
# Reusable prompt fields that can be shared across email-related flows

resource "authentik_stage_prompt_field" "first_name" {
  name                   = "prompt-field-first-name"
  field_key              = "first_name"
  label                  = "First Name"
  type                   = "text"
  required               = true
  placeholder            = "Enter your first name"
  placeholder_expression = false
}

resource "authentik_stage_prompt_field" "last_name" {
  name                   = "prompt-field-last-name"
  field_key              = "last_name"
  label                  = "Last Name"
  type                   = "text"
  required               = true
  placeholder            = "Enter your last name"
  placeholder_expression = false
}
