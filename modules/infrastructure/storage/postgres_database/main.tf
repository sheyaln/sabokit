# Provisions one database + matching user + password + Scaleway secret inside
# an existing managed PostgreSQL instance. App bundles use this to own their
# own database without each having to bake in 5 raw resources.

locals {
  resolved_user_name = var.user_name != null ? var.user_name : var.database_name
}

resource "random_password" "this" {
  count            = var.credentials_preserve ? 0 : 1
  length           = 32
  special          = true
  override_special = "@+=:,._-"
  min_numeric      = 1

  lifecycle {
    ignore_changes = [override_special, min_numeric, length]
  }
}

# In-place cutover: read the existing per-db credentials bag and reuse the
# password so the existing rdb user keeps the same secret.
data "scaleway_secret" "preserved" {
  count = var.credentials_preserve ? 1 : 0
  name  = "postgres-${var.database_name}-credentials"
}

data "scaleway_secret_version" "preserved" {
  count     = var.credentials_preserve ? 1 : 0
  secret_id = data.scaleway_secret.preserved[0].id
  revision  = "latest"
}

locals {
  _preserved = var.credentials_preserve ? jsondecode(base64decode(data.scaleway_secret_version.preserved[0].data)) : {}
  password   = var.credentials_preserve ? local._preserved.password : random_password.this[0].result
}

resource "scaleway_rdb_database" "this" {
  name        = var.database_name
  instance_id = var.instance_id
}

resource "scaleway_rdb_user" "this" {
  name        = local.resolved_user_name
  password    = local.password
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
  count = var.credentials_preserve ? 0 : 1

  name        = "postgres-${var.database_name}-credentials"
  description = "Database credentials for ${var.database_name}"
  tags        = distinct(concat(var.tags, ["postgres"]))
  type        = "database_credentials"
}

resource "scaleway_secret_version" "this" {
  count = var.credentials_preserve ? 0 : 1

  secret_id = scaleway_secret.this[0].id
  data = jsonencode({
    dbname   = scaleway_rdb_database.this.name
    engine   = var.engine
    username = scaleway_rdb_user.this.name
    password = local.password
    host     = var.instance_endpoint.ip
    port     = tostring(var.instance_endpoint.port)
  })
  description = "Database credentials for ${var.database_name}"

  lifecycle {
    # Scaleway's API doesn't return secret values on read; after `terraform
    # import` the refreshed `data` is null and re-render looks like a
    # forces_replacement diff — destroying live DB creds. Lock the version.
    # Rotate by tainting this resource.
    ignore_changes = [data]
  }
}
