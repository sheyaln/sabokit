locals {
  slug = "grafana"

  authorized_groups = var.enabled ? merge(
    { (var.access_level) = var.base.authentik.groups[var.access_level] },
    var.extra_authorized_groups,
  ) : {}

  app_url           = "https://${var.hostname}"
  oidc_callback_url = "https://${var.hostname}/login/generic_oauth"
}
