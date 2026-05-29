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
  description = "ID of the Proxy Provider"
  value       = authentik_provider_proxy.provider.id
}

output "provider_name" {
  description = "Name of the Proxy Provider"
  value       = authentik_provider_proxy.provider.name
}

output "external_host" {
  description = "External host URL protected by this provider"
  value       = var.external_host
}
