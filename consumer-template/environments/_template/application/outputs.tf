# Consumed by the application Ansible play (terraform output -json enabled_apps).

output "enabled_apps" {
  description = "Per-app dispatch map the application play deploys. backrest is a nested {instances=...} map."
  value       = module.application.enabled_apps
  sensitive   = true
}

output "outpost_id" {
  description = "Embedded forward-auth outpost ID the application layer manages."
  value       = module.application.outpost_id
}
