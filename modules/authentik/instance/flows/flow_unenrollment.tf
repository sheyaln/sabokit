# USER UNENROLLMENT FLOW
# 
# This flow allows authenticated users to delete their own accounts from the
# system. It provides a self-service account deletion option.
# 
# Based on the Authentik blueprint: Example - User deletion

# BASIC UNENROLLMENT FLOW
# Main flow for user account deletion
resource "authentik_flow" "default_unenrollment_flow" {
  name               = "Default unenrollment flow"
  title              = "Delete your account"
  slug               = "default-unenrollment-flow"
  designation        = "unenrollment"
  authentication     = "require_authenticated"
  layout             = "stacked"
  denied_action      = "message"
  policy_engine_mode = "all"
  compatibility_mode = false
}

# BASIC USER DELETE STAGE (Matching Original Blueprint)
# User delete stage - actually deletes the user account
resource "authentik_stage_user_delete" "default_unenrollment_user_delete" {
  name = "default-unenrollment-user-delete"
}

# BASIC FLOW STAGE BINDING (Matching Original Blueprint)
# Binding the delete stage to the flow
resource "authentik_flow_stage_binding" "unenrollment_delete_binding" {
  target               = authentik_flow.default_unenrollment_flow.uuid
  stage                = authentik_stage_user_delete.default_unenrollment_user_delete.id
  order                = 10
  evaluate_on_plan     = true
  re_evaluate_policies = true
}

# ENHANCED FEATURES (Optional - Can be enabled/disabled)

# Confirmation prompt stage for account deletion (Enhanced feature)
resource "authentik_stage_prompt" "unenrollment_confirmation" {
  name = "unenrollment-confirmation-prompt"
  fields = [
    authentik_stage_prompt_field.confirm_deletion.id,
  ]
}

# Confirmation field - user must type DELETE to confirm
resource "authentik_stage_prompt_field" "confirm_deletion" {
  name                   = "prompt-field-confirm-deletion"
  field_key              = "confirm_deletion"
  label                  = "Type 'DELETE' to confirm account deletion (Warning: This cannot be undone)"
  type                   = "text"
  required               = true
  placeholder            = "Type DELETE to confirm"
  placeholder_expression = false
}


# ENHANCED FLOW WITH CONFIRMATION (Optional Configuration)
# To enable the confirmation prompt, uncomment the following binding
# and update the delete binding order to 20

# resource "authentik_flow_stage_binding" "unenrollment_confirmation_binding" {
#   target               = authentik_flow.default_unenrollment_flow.uuid
#   stage                = authentik_stage_prompt.unenrollment_confirmation.id
#   order                = 10
#   evaluate_on_plan     = true
#   re_evaluate_policies = true
# }

# SECURITY POLICIES (Enhanced features)

# Policy to validate deletion confirmation (use with confirmation prompt)
resource "authentik_policy_expression" "validate_deletion_confirmation" {
  name              = "policy-validate-deletion-confirmation"
  execution_logging = true
  expression        = <<-EOT
    # Check if user typed DELETE to confirm
    confirmation = request.context.get('prompt_data', {}).get('confirm_deletion', '')
    
    if confirmation and confirmation.upper() != 'DELETE':
        ak_message("Please type DELETE to confirm account deletion")
        return False
    
    return True
  EOT
}

# Policy to prevent admin users from deleting their accounts
resource "authentik_policy_expression" "prevent_admin_deletion" {
  name              = "policy-prevent-admin-deletion"
  execution_logging = true
  expression        = <<-EOT
    # Prevent admin users from deleting their accounts
    if request.user.is_superuser:
        ak_message("Admin accounts cannot be deleted through self-service")
        return False
    
    # Check if user is in admin group
    admin_groups = ["admin", "union-delegate"]
    user_groups = [group.name for group in request.user.ak_groups.all()]
    
    for admin_group in admin_groups:
        if admin_group in user_groups:
            ak_message(f"Users in {admin_group} group cannot delete their accounts through self-service")
            return False
    
    return True
  EOT
}

# SECURITY POLICY BINDINGS (Optional - Uncomment to enable)

# Uncomment to bind admin prevention policy to the flow
# resource "authentik_policy_binding" "prevent_admin_deletion_binding" {
#   target  = authentik_flow.default_unenrollment_flow.uuid
#   policy  = authentik_policy_expression.prevent_admin_deletion.id
#   order   = 0
#   enabled = true
#   timeout = 30
# }

# Uncomment to bind deletion confirmation validation to the confirmation prompt
# (Only use if confirmation prompt is enabled)
# resource "authentik_policy_binding" "deletion_confirmation_binding" {
#   target  = authentik_flow_stage_binding.unenrollment_confirmation_binding.id
#   policy  = authentik_policy_expression.validate_deletion_confirmation.id
#   order   = 0
#   enabled = true
#   timeout = 30
# }