resource "authentik_brand" "default" {
  domain  = var.gateway_domain
  default = true

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
  flow_user_settings  = module.flows.default_user_settings_flow_id
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
