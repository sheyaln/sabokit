# Policy fired from the welcome stage of any enrollment flow. Posts to a
# webhook (if configured) and emails the admin-tier groups.

resource "authentik_policy_expression" "new_user_notification" {
  name              = "policy-new-user-notification"
  execution_logging = true
  expression = templatefile("${path.module}/../expressions/policy-new-user-notification.py.tpl", {
    webhook_url        = var.notification_webhook_url
    domain             = var.domain
    organisation_name  = var.organisation_name
    target_groups_json = local.admin_tier_group_names_json
  })
}

# Bind to Source Enrollment Welcome Stage
resource "authentik_policy_binding" "source_enrollment_notification_binding" {
  target  = authentik_flow_stage_binding.source_enrollment_welcome_binding.id
  policy  = authentik_policy_expression.new_user_notification.id
  order   = 0
  enabled = true
  timeout = 30
}

# Bind to Manual Enrollment Welcome Stage
resource "authentik_policy_binding" "manual_enrollment_notification_binding" {
  target  = authentik_flow_stage_binding.manual_enrollment_welcome_binding.id
  policy  = authentik_policy_expression.new_user_notification.id
  order   = 0
  enabled = true
  timeout = 30
}
