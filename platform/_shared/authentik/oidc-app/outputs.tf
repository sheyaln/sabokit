output "application_uuid" {
  description = "UUID of the created application."
  value       = authentik_application.application.uuid
}

output "application_slug" {
  description = "Slug of the created application."
  value       = authentik_application.application.slug
}

output "application_group_id" {
  description = "ID of the per-app Authentik group (used for service accounts that need direct access)."
  value       = authentik_group.application.id
}

output "provider_id" {
  description = "ID of the OIDC provider."
  value       = authentik_provider_oauth2.provider.id
}

output "client_id" {
  description = "OIDC client ID."
  value       = authentik_provider_oauth2.provider.client_id
}

output "client_secret" {
  description = "OIDC client secret. Prefer reading from scaleway_secret_id when possible."
  value       = authentik_provider_oauth2.provider.client_secret
  sensitive   = true
}

output "scaleway_secret_id" {
  description = "ID of the Scaleway secret holding OIDC credentials. Consumers (typically Ansible) should fetch from here rather than embedding the values in Terraform state."
  value       = scaleway_secret.app_secret.id
}
