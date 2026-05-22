# User-lifecycle event wiring.
#
# Two event matchers (model_created and model_updated on authentik_core.user)
# feed an event rule with a local transport. When a webhook URL is configured
# an additional expression policy is bound to the same rule; the policy posts
# to the webhook and sends fallback emails to admin/delegate group members.

# ── Event matchers ──────────────────────────────────────────────────────────

resource "authentik_policy_event_matcher" "user_updated" {
  name              = "policy-event-user-updated"
  action            = "model_updated"
  model             = "authentik_core.user"
  app               = "authentik.core"
  execution_logging = true
}

resource "authentik_policy_event_matcher" "user_created" {
  name   = "policy-event-user-created"
  action = "model_created"
  model  = "authentik_core.user"
  app    = "authentik.core"
}

# ── Transport + rule ────────────────────────────────────────────────────────

# Local transport is a no-op delivery; the work happens in the expression
# policy below. Authentik still requires a transport on the rule.
resource "authentik_event_transport" "local_notifications" {
  name      = "local-notifications"
  mode      = "local"
  send_once = true
}

resource "authentik_event_rule" "user_activated_notification" {
  name       = "user-activated-notification"
  severity   = "notice"
  transports = [authentik_event_transport.local_notifications.id]
}

resource "authentik_policy_binding" "user_activated_event_matcher_binding" {
  target  = authentik_event_rule.user_activated_notification.id
  policy  = authentik_policy_event_matcher.user_updated.id
  order   = 0
  enabled = true
  timeout = 30
}

# ── Webhook expression policy (only when webhook URL is configured) ─────────

resource "authentik_policy_expression" "user_activated_send_email" {
  count             = var.notification_webhook_url != "" ? 1 : 0
  name              = "policy-user-activated-send-email"
  execution_logging = true
  expression = templatefile("${path.module}/expressions/policy-user-activation-notification.py.tpl", {
    webhook_url                  = var.notification_webhook_url
    tools_domain                 = var.base_domain
    gateway_domain               = var.gateway_domain
    org_name                     = var.org_name
    test_mode                    = var.notification_test_mode ? "True" : "False"
    target_groups_json           = local.notification_target_groups_json
    test_target_groups_json      = local.notification_test_target_groups_json
    support_contact_instructions = var.notification_support_contact_instructions
    welcome_message              = var.notification_welcome_message
  })
}

resource "authentik_policy_binding" "user_activated_send_email_binding" {
  count   = var.notification_webhook_url != "" ? 1 : 0
  target  = authentik_event_rule.user_activated_notification.id
  policy  = authentik_policy_expression.user_activated_send_email[0].id
  order   = 10
  enabled = true
  timeout = 30
}
