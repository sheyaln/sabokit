output "application_uuid" {
  description = "UUID of the created application."
  value       = authentik_application.application.uuid
}

output "application_slug" {
  description = "Slug of the created application."
  value       = authentik_application.application.slug
}

output "application_group_id" {
  description = "ID of the per-app Authentik group."
  value       = authentik_group.application.id
}

output "provider_id" {
  description = "ID of the SAML provider."
  value       = authentik_provider_saml.provider.id
}

output "saml_metadata_url_path" {
  description = "SAML metadata URL path (append to https://<authentik-host>)."
  value       = "/application/saml/${var.application_slug}/metadata/"
}

output "saml_sso_url_path" {
  description = "SAML SSO URL path (append to https://<authentik-host>)."
  value       = "/application/saml/${var.application_slug}/sso/binding/${var.saml_service_provider_binding}/"
}

output "saml_slo_url_path" {
  description = "SAML SLO URL path (append to https://<authentik-host>)."
  value       = "/application/saml/${var.application_slug}/slo/binding/${var.saml_service_provider_binding}/"
}

output "scaleway_secret_id" {
  description = "ID of the Scaleway secret holding SAML configuration."
  value       = scaleway_secret.app_secret.id
}
