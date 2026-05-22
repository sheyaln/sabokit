# AUTHENTIK EMBEDDED OUTPOST FOR TRAEFIK FORWARD AUTH
#
# The embedded outpost is automatically created by Authentik and handles
# forward auth requests at /outpost.goauthentik.io/auth/traefik
#
# We use a data source to look it up and manage it to bind our proxy providers.

# Data source to look up the embedded outpost by its name
data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

# Manage the embedded outpost to bind our proxy providers
resource "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
  type = "proxy"

  # Bind all forward auth proxy providers to the embedded outpost
  # Per-host Backrest instances for backup management
  protocol_providers = [
    module.backrest_mgmt.provider_id,
    module.backrest_tools.provider_id,
    module.backrest_gateway.provider_id,
    module.bentopdf.provider_id,
  ]

  config = jsonencode({
    authentik_host          = "https://${var.gateway_domain}/"
    authentik_host_browser  = "https://${var.gateway_domain}/"
    authentik_host_insecure = false
    log_level               = "info"
    object_naming_template  = "ak-outpost-%(name)s"
    refresh_interval        = "minutes=5"
  })

  lifecycle {
    # Prevent Terraform from trying to delete the embedded outpost
    prevent_destroy = true

    # Ignore changes to service_connection - Authentik manages this for embedded outpost
    ignore_changes = [
      service_connection,
    ]
  }
}
