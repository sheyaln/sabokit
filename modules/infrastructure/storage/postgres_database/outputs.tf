output "database_name" {
  description = "Name of the created database."
  value       = scaleway_rdb_database.this.name
}

output "user_name" {
  description = "Name of the created database user."
  value       = scaleway_rdb_user.this.name
}

output "password" {
  description = "Password for the user (generated or preserved). Prefer reading from secret_id."
  value       = local.password
  sensitive   = true
}

output "secret_id" {
  description = "Scaleway secret holding {dbname, engine, username, password, host, port}."
  value       = var.credentials_preserve ? data.scaleway_secret.preserved[0].id : scaleway_secret.this[0].id
}
