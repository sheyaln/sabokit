resource "authentik_brand" "default" {
  domain = var.identity_domain

  # Authentik auto-creates exactly one default-fallback brand on first boot
  # (domain="authentik-default"), and refuses a second `default = true`. We
  # leave the auto-default in place as the catch-all and match-by-domain
  # routes requests to identity_domain into THIS brand. Set default = true
  # manually post-deploy if you want this brand to also be the fallback.
  default = false

  branding_title                   = "${var.org_name} Gateway"
  branding_logo                    = var.branding_logo
  branding_favicon                 = var.branding_favicon
  branding_default_flow_background = var.branding_default_flow_background

  branding_custom_css = file("${path.module}/assets/branding.css")

  lifecycle {
    ignore_changes = [branding_custom_css]
  }

  flow_authentication = module.flows.authentication_flow_login
  flow_invalidation   = module.flows.default_invalidation_flow_id
  flow_user_settings  = module.flows.user_settings_flow_uuid
  flow_recovery       = module.flows.password_reset_flow_uuid
  flow_unenrollment   = module.flows.default_unenrollment_flow_uuid

  # Per-user/per-group attributes can still override these UI defaults.
  attributes = jsonencode({
    settings = {
      navbar = {
        userDisplay = "username"
      }
      theme = {
        base = "automatic"
      }
      enabledFeatures = {
        apiDrawer          = false
        applicationEdit    = false
        notificationDrawer = true
        search             = true
        settings           = true
      }
    }
  })
}
