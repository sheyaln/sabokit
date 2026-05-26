# Outputs consumed by:
#   - The consumer's deploy.sh, which reads `admin_secret_id` to fetch the
#     api_token and export it as TF_VAR_authentik_admin_token before phase 3
#     applies the rest of the identity bundle.
#   - platform/ansible/bootstrap.yml, which expects an `identity_bootstrap`
#     extra-var shaped as below.

output "identity_bootstrap" {
  description = "Map consumed verbatim by platform/ansible/bootstrap.yml via -e identity_bootstrap=...; each *_secret_id is a Scaleway Secret Manager ID the authentik-server role hands to the scaleway_secret lookup plugin. media_s3_secret_id + smtp_secret_id default to empty and only need values when those Authentik features are turned on."
  value = {
    postgres_secret_id = module.database.secret_id
    admin_secret_id    = scaleway_secret.admin.id
    server_secret_id   = scaleway_secret.server.id
    media_s3_secret_id = var.media_s3_secret_id
    smtp_secret_id     = var.smtp_secret_id
  }
}

output "admin_secret_id" {
  description = "Scaleway secret ID for the admin credentials JSON {username, email, password, api_token}. Use `scw secret version access` to fetch the api_token for the Terraform authentik provider."
  value       = scaleway_secret.admin.id
}

output "server_secret_id" {
  description = "Scaleway secret ID for the Authentik server-side secret_key."
  value       = scaleway_secret.server.id
}

output "database_secret_id" {
  description = "Scaleway secret ID for the authentik PostgreSQL database credentials."
  value       = module.database.secret_id
}
