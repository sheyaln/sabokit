# Embedded outpost. Authentik creates it implicitly on first boot. We declare
# a matching resource so we can pin `protocol_providers` from app bundles
# that need forward-auth (Backrest, BentoPDF, etc.).
#
# The first-apply collision (Authentik returns "Outpost with this name
# already exists.") is resolved by consumer-template/scripts/deploy.sh,
# which runs `terraform import` on this address BEFORE phase 5's apply,
# only when the resource isn't already in state. A root-level `import {}`
# block would be cleaner — but those don't work inside child modules in
# Terraform 1.5+, and requiring every consumer to add boilerplate in
# their per-env main.tf breaks the drop-in-module contract. The deploy.sh
# shim keeps the experience one-shot.
#
# Provider IDs come from `var.extra_forward_auth_provider_ids` which the
# consumer assembles by compact()-ing the authentik_provider_id outputs of
# every enabled forward-auth app. See ARCHITECTURE.md "Outpost binding
# mechanism" for the consumer-side wiring and the first-apply cycle note.

data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

resource "authentik_outpost" "embedded" {
  # Only manage the outpost when there's actually something to bind. The
  # Authentik API refuses to PATCH `providers` with an empty list, and a
  # consumer who hasn't enabled any forward-auth apps doesn't need us
  # touching the embedded outpost at all.
  count = length(var.extra_forward_auth_provider_ids) > 0 ? 1 : 0

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
