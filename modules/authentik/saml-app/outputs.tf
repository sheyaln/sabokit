output "application_uuid" {
  description = "UUID of the created application"
  value       = authentik_application.application.uuid
}

output "application_group_id" {
  description = "ID of the Authentik group created for this application"
  value       = authentik_group.application.id
}

output "application_slug" {
  description = "Slug of the created application"
  value       = authentik_application.application.slug
}

output "provider_id" {
  description = "ID of the SAML provider"
  value       = authentik_provider_saml.provider.id
}

output "saml_metadata_url" {
  description = "SAML metadata URL path"
  value       = "/application/saml/${var.application_slug}/metadata/"
}

output "saml_sso_url" {
  description = "SAML SSO URL path"
  value       = "/application/saml/${var.application_slug}/sso/binding/${var.saml_service_provider_binding}/"
}

output "saml_slo_url" {
  description = "SAML SLO URL path"
  value       = "/application/saml/${var.application_slug}/slo/binding/${var.saml_service_provider_binding}/"
}
