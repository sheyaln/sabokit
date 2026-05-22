# Policy to send email and Slack notification to admins/delegates when a new user reaches the welcome stage
resource "authentik_policy_expression" "new_user_notification" {
  name              = "policy-new-user-notification"
  execution_logging = true
  expression = templatefile("${path.module}/../expressions/policy-new-user-notification.py.tpl", {
    n8n_webhook_url   = var.n8n_webhook_user_notifications
    domain            = var.domain
    organisation_name = var.organisation_name
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
