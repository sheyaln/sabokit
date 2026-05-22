# Provisions one database + matching user + password + Scaleway secret inside
# an existing managed PostgreSQL instance. App bundles use this to own their
# own database without each having to bake in 5 raw resources.

locals {
  resolved_user_name = var.user_name != null ? var.user_name : var.database_name
}

resource "random_password" "this" {
  length           = 32
  special          = true
  override_special = "!@+=:,._-"
  min_numeric      = 1

  lifecycle {
    ignore_changes = [override_special, min_numeric, length]
  }
}

resource "scaleway_rdb_database" "this" {
  name        = var.database_name
  instance_id = var.instance_id
}

resource "scaleway_rdb_user" "this" {
  name        = local.resolved_user_name
  password    = random_password.this.result
  is_admin    = var.is_admin
  instance_id = var.instance_id

  depends_on = [scaleway_rdb_database.this]
}

resource "scaleway_rdb_privilege" "this" {
  user_name     = scaleway_rdb_user.this.name
  database_name = scaleway_rdb_database.this.name
  instance_id   = var.instance_id
  permission    = var.permission
}

resource "scaleway_secret" "this" {
  name        = "postgres-${var.database_name}-credentials"
  description = "Database credentials for ${var.database_name}"
  tags        = concat(var.tags, ["postgres"])
  type        = "database_credentials"
}

resource "scaleway_secret_version" "this" {
  secret_id = scaleway_secret.this.id
  data = jsonencode({
    dbname   = scaleway_rdb_database.this.name
    engine   = var.engine
    username = scaleway_rdb_user.this.name
    password = random_password.this.result
    host     = var.instance_endpoint.ip
    port     = tostring(var.instance_endpoint.port)
  })
  description = "Database credentials for ${var.database_name}"
}
