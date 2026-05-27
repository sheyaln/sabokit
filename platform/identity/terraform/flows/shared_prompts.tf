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

# =============================================================================
# MEMBER_ID NORMALIZE + UNIQUENESS
# =============================================================================
# Both policies attach as `validation_policies` on every prompt stage that
# carries a member_id field: manual-enrollment, source-enrollment profile, and
# user-settings. Order in `validation_policies` is the order they execute, so
# normalize MUST be listed before unique — the unique check reads the value
# normalize wrote back.
#
# The user_settings prompt uses field_key="attributes.member_id" (so user_write
# nests it under user.attributes); the enrollment flows use bare "member_id"
# (user_write writes non-User-model prompt_data keys to attributes anyway).
# Both policies handle either key.

# Strip + lowercase member_id in prompt_data so the unique check + downstream
# storage all see a single canonical form. Empty values pass through unchanged
# (member_id is optional).
resource "authentik_policy_expression" "shared_member_id_normalize" {
  name              = "policy-shared-member-id-normalize"
  execution_logging = true
  expression        = <<-EOT
    prompt_data = request.context.get('prompt_data', {}) or {}
    # Either key may carry the value depending on the prompt field_key the
    # calling flow uses. Whichever one is set, normalize in place.
    for key in ('member_id', 'attributes.member_id'):
        value = prompt_data.get(key)
        if value is None:
            continue
        prompt_data[key] = str(value).strip().lower()
    request.context['prompt_data'] = prompt_data
    return True
  EOT
}

# Reject when ANOTHER user already has this member_id (case-insensitive,
# whitespace-stripped — relies on normalize running first). Empty values pass
# through (optional field). Excludes pending_user.pk (the user being modified
# by the flow) so re-saving without changing member_id doesn't self-collide.
# pending_user.pk is the right identifier — request.user is the *submitter*
# (which happens to equal the modified user on self-edits + is anonymous on
# enrollments, but would diverge on any hypothetical admin-edits-other flow).
resource "authentik_policy_expression" "shared_member_id_unique" {
  name              = "policy-shared-member-id-unique"
  execution_logging = true
  expression        = <<-EOT
    prompt_data = request.context.get('prompt_data', {}) or {}
    member_id = prompt_data.get('member_id') or prompt_data.get('attributes.member_id') or ''
    member_id = str(member_id).strip().lower()
    if not member_id:
        return True

    try:
        from authentik.core.models import User
        # member_id lives in the JSONField user.attributes. iexact against
        # already-normalized incoming + attribute may be missing on legacy users.
        qs = User.objects.filter(attributes__member_id__iexact=member_id)

        # pending_user is the user the flow is editing/creating. On self-edits
        # that's request.user; on admin-edits-other that's the target user; on
        # enrollment (new user) pk is None so no exclusion happens.
        pending_user = request.context.get('pending_user', None)
        pending_pk = getattr(pending_user, 'pk', None)
        if pending_pk:
            qs = qs.exclude(pk=pending_pk)

        if qs.exists():
            ak_message("That member ID is already in use. Leave the field blank or pick a different value.")
            return False
    except Exception as e:
        ak_logger.error(f"Error checking member_id uniqueness: {e}")
        # Fail open — don't block legitimate users on a query bug. This is a
        # data-quality nudge, not a security boundary.
        return True

    return True
  EOT
}
