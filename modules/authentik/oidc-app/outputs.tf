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
  description = "ID of the OIDC provider"
  value       = authentik_provider_oauth2.provider.id
}

output "client_id" {
  description = "OIDC client ID"
  value       = authentik_provider_oauth2.provider.client_id
}

output "client_secret" {
  description = "OIDC client secret"
  value       = authentik_provider_oauth2.provider.client_secret
  sensitive   = true
}
