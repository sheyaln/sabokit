# Wazuh dashboard's SSO config doesn't natively speak OIDC at the bundle
# level (it's OpenSearch-based; full OIDC requires writing config.yml for
# the opensearch-security plugin). We protect it via Authentik's forward-auth
# at the gateway instead: authenticated users land inside on the dashboard's
# built-in admin account. provider_id MUST be added to identity's
# extra_forward_auth_provider_ids list.

module "authentik" {
  source = "../../../../modules/authentik/traefik-forward-auth"
  count  = var.enabled ? 1 : 0

  application_name = "Wazuh"
  application_slug = local.slug
  category_group   = var.category_group
  icon_url         = var.icon_url
  description      = "SIEM + endpoint detection"
  external_host    = local.app_url
  launch_url       = local.app_url

  authorized_groups = local.authorized_groups

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow
}
