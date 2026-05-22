output "database_name" {
  description = "Name of the created database."
  value       = scaleway_rdb_database.this.name
}

output "user_name" {
  description = "Name of the created database user."
  value       = scaleway_rdb_user.this.name
}

output "password" {
  description = "Generated password for the user. Prefer reading from secret_id."
  value       = random_password.this.result
  sensitive   = true
}

output "secret_id" {
  description = "Scaleway secret holding {dbname, engine, username, password, host, port}."
  value       = scaleway_secret.this.id
}
