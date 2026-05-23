locals {
  slug = "espocrm"

  authorized_groups = var.enabled ? merge(
    { (var.access_level) = var.base.authentik.groups[var.access_level] },
    var.extra_authorized_groups,
  ) : {}

  # EspoCRM's OIDC redirect URI is the site root — Espo intercepts the
  # /?action=oauthCallback pattern internally rather than exposing a dedicated path.
  oidc_callback_url = "https://${var.hostname}/oauth-callback.php"
  oidc_logout_url   = "https://${var.base.authentik.gateway_domain}/application/o/${local.slug}/end-session/"
  app_url           = "https://${var.hostname}"
}
