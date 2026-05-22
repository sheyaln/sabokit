# Embedded outpost. Authentik creates it implicitly on first boot; we look it
# up and manage it so we can bind forward-auth providers from app bundles.
#
# Provider IDs come from `var.extra_forward_auth_provider_ids` which the
# consumer assembles by compact()-ing the authentik_provider_id outputs of
# every enabled forward-auth app. See ARCHITECTURE.md "Outpost binding
# mechanism" for the consumer-side wiring and the first-apply cycle note.

data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

resource "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
  type = "proxy"

  protocol_providers = var.extra_forward_auth_provider_ids

  config = jsonencode({
    authentik_host          = "https://${var.gateway_domain}/"
    authentik_host_browser  = "https://${var.gateway_domain}/"
    authentik_host_insecure = false
    log_level               = "info"
    object_naming_template  = "ak-outpost-%(name)s"
    refresh_interval        = "minutes=5"
  })

  lifecycle {
    # Authentik refuses to delete the embedded outpost anyway; this makes the
    # intent explicit and protects against an accidental `destroy`.
    prevent_destroy = true
    # The embedded outpost has its service connection managed by Authentik
    # itself, not by Terraform.
    ignore_changes = [service_connection]
  }
}
