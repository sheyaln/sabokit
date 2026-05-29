# Forward-auth — Backrest's built-in auth is disabled (config.json sets
# `auth.disabled=true`) so Authentik's embedded outpost is the ONLY gate.
# The exported provider_id must be added to identity's
# `extra_forward_auth_provider_ids` for the outpost to protect this instance.

module "authentik" {
  source = "../../../../modules/authentik/traefik-forward-auth"
  count  = var.enabled ? 1 : 0

  application_name = var.application_name != "" ? var.application_name : "Backrest (${var.instance_name})"
  application_slug = local.qualified_slug
  category_group   = var.category_group
  icon_url         = local.effective_icon_url
  description      = "Restic backups for ${var.instance_name}"
  external_host    = local.app_url
  launch_url       = local.app_url

  authorized_groups = local.authorized_groups

  authentication_flow_uuid = var.base.authentik.flows.authentication_flow
  authorization_flow_uuid  = var.base.authentik.flows.authorization_flow
  invalidation_flow_uuid   = var.base.authentik.flows.invalidation_flow
}
