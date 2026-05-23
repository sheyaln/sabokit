locals {
  slug = "bentopdf"

  authorized_groups = var.enabled ? merge(
    { (var.access_level) = var.base.authentik.groups[var.access_level] },
    var.extra_authorized_groups,
  ) : {}

  app_url = "https://${var.hostname}"
}
