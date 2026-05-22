output "application_uuid" {
  description = "UUID of the created bookmark application"
  value       = authentik_application.bookmark.uuid
}

output "application_slug" {
  description = "Slug of the created bookmark application"
  value       = authentik_application.bookmark.slug
}

output "application_name" {
  description = "Name of the created bookmark application"
  value       = authentik_application.bookmark.name
}

output "launch_url" {
  description = "Launch URL of the bookmark application"
  value       = authentik_application.bookmark.meta_launch_url
}
