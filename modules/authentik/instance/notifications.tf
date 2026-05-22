# EVENT NOTIFICATIONS
#
# This file configures Authentik event-based notifications for user lifecycle events.
# Notifications are sent to n8n webhook which handles:
#   - Slack messages with threading (activation replies to signup)
#   - Email notifications to users and admins

# =============================================================================
# CONFIGURATION
# =============================================================================

locals {
  # Set to true to only notify admin group (for testing)
  # Set to false to notify both admin and union-delegate groups (production)
  activation_test_mode = true
}

# =============================================================================
# EVENT MATCHERS
# =============================================================================

# Event Matcher Policy - matches user model updates
resource "authentik_policy_event_matcher" "user_updated" {
  name              = "policy-event-user-updated"
  action            = "model_updated"
  model             = "authentik_core.user"
  app               = "authentik.core"
  execution_logging = true
}

# Event Matcher Policy - matches user model creation
resource "authentik_policy_event_matcher" "user_created" {
  name   = "policy-event-user-created"
  action = "model_created"
  model  = "authentik_core.user"
  app    = "authentik.core"
}

# =============================================================================
# USER ACTIVATION NOTIFICATIONS
# =============================================================================

# Expression policy to send email when user is activated
# This runs when a user model is updated and checks if is_active changed to true
# Sends notifications to both the activated user AND admins/delegates
resource "authentik_policy_expression" "user_activated_send_email" {
  name              = "policy-user-activated-send-email"
  execution_logging = true
  expression = templatefile("${path.module}/expressions/policy-user-activation-notification.py.tpl", {
    n8n_webhook_url = local.n8n_webhook_user_notifications
    tools_domain    = var.domain
    org_name        = var.org_name
    test_mode       = local.activation_test_mode ? "True" : "False"
  })
}

# Local transport for internal notifications (no external delivery)
# Used as a placeholder since the expression policy handles email directly
resource "authentik_event_transport" "local_notifications" {
  name      = "local-notifications"
  mode      = "local"
  send_once = true
}

# Event rule that processes user activation events
# The expression policy sends webhook to n8n which handles notifications
resource "authentik_event_rule" "user_activated_notification" {
  name     = "user-activated-notification"
  severity = "notice"
  # Use local transport since the expression policy sends the webhook directly
  transports = [authentik_event_transport.local_notifications.id]
}

# Bind the event matcher to filter for user updates
resource "authentik_policy_binding" "user_activated_event_matcher_binding" {
  target  = authentik_event_rule.user_activated_notification.id
  policy  = authentik_policy_event_matcher.user_updated.id
  order   = 0
  enabled = true
  timeout = 30
}

# Bind the expression policy to send the email
resource "authentik_policy_binding" "user_activated_send_email_binding" {
  target  = authentik_event_rule.user_activated_notification.id
  policy  = authentik_policy_expression.user_activated_send_email.id
  order   = 10
  enabled = true
  timeout = 30
}
