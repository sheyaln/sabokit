# TEM delivery-event webhook → SNS → n8n. Optional; activates when an n8n
# webhook URL is supplied alongside enabled TEM. Disabling either emits zero
# resources, so consumers can wire/unwire by toggling a single var.
#
# Topology:
#   Scaleway TEM → SNS topic → HTTPS subscription → n8n /webhook/<path>
#
# Lives in base because TEM lives in base. The consumer-template feeds
# var.tem_webhook_n8n_url from `module.n8n[0].app_url` (when n8n is enabled),
# so the lifecycle stays inside the consumer-controlled module call.

resource "scaleway_mnq_sns" "main" {
  count      = local.tem_webhook_enabled ? 1 : 0
  project_id = var.scaleway_project_id
}

resource "scaleway_mnq_sns_credentials" "tem_alerting" {
  count      = local.tem_webhook_enabled ? 1 : 0
  project_id = scaleway_mnq_sns.main[0].project_id
  name       = "${local.name_suffix}-tem-alerting"

  permissions {
    can_publish = true
    can_receive = true
    can_manage  = true
  }
}

resource "scaleway_mnq_sns_topic" "tem_events" {
  count      = local.tem_webhook_enabled ? 1 : 0
  project_id = scaleway_mnq_sns.main[0].project_id
  name       = var.tem_webhook_sns_topic_name
  access_key = scaleway_mnq_sns_credentials.tem_alerting[0].access_key
  secret_key = scaleway_mnq_sns_credentials.tem_alerting[0].secret_key
}

resource "scaleway_mnq_sns_topic_subscription" "n8n_webhook" {
  count      = local.tem_webhook_enabled ? 1 : 0
  project_id = scaleway_mnq_sns.main[0].project_id
  access_key = scaleway_mnq_sns_credentials.tem_alerting[0].access_key
  secret_key = scaleway_mnq_sns_credentials.tem_alerting[0].secret_key
  topic_id   = scaleway_mnq_sns_topic.tem_events[0].id
  protocol   = "https"
  endpoint   = "${var.tem_webhook_n8n_url}${var.tem_webhook_n8n_path}"
}

resource "scaleway_tem_webhook" "delivery_alerts" {
  count = local.tem_webhook_enabled ? 1 : 0

  domain_id   = scaleway_tem_domain.this[0].id
  name        = "${local.name_suffix}-tem-delivery"
  event_types = var.tem_webhook_event_types
  sns_arn     = scaleway_mnq_sns_topic.tem_events[0].arn
}
