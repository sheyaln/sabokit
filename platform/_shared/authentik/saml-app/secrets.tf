# ── Scaleway Secret for SAML Configuration ───────────────────────────────────

resource "scaleway_secret" "app_secret" {
  name        = "authentik-app-${var.application_slug}"
  description = "${var.application_name} SAML credentials"
  type        = "key_value"
  tags        = ["authentik", var.application_slug, "saml"]
}

resource "scaleway_secret_version" "saml_credentials" {
  secret_id = scaleway_secret.app_secret.id
  data = jsonencode({
    provider_type = "saml"

    acs_url    = var.saml_assertion_consumer_service_url
    audience   = var.saml_audience
    sp_binding = var.saml_service_provider_binding

    metadata_url = "/application/saml/${var.application_slug}/metadata/"
    sso_url      = "/application/saml/${var.application_slug}/sso/binding/${var.saml_service_provider_binding}/"
    slo_url      = "/application/saml/${var.application_slug}/slo/binding/${var.saml_service_provider_binding}/"

    sign_assertion      = tostring(var.saml_sign_assertion)
    digest_algorithm    = var.saml_digest_algorithm
    signature_algorithm = var.saml_signature_algorithm
    default_relay_state = var.saml_default_relay_state != null ? var.saml_default_relay_state : ""
  })

  lifecycle {
    # Scaleway's API doesn't return secret values on read; after `terraform
    # import` the refreshed `data` is null and re-render looks like a
    # forces_replacement diff. Locking the version keeps imported secrets
    # intact. Rotate by tainting this resource.
    ignore_changes = [data]
  }
}
