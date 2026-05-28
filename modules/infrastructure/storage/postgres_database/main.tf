# Provisions one database + matching user + password + Scaleway secret inside
# an existing managed PostgreSQL instance. App bundles use this to own their
# own database without each having to bake in 5 raw resources.

locals {
  resolved_user_name = var.user_name != null ? var.user_name : var.database_name
}

resource "random_password" "this" {
  count            = 1
  length           = 32
  special          = true
  override_special = "@!"
  min_numeric      = 1
  # Scaleway's RDB password constraint requires at least one [!@#$%^&*]-class
  # special. Restricting override_special to {@,!} guarantees every drawn
  # special satisfies that constraint — previous "._-@!" set was uniform-sampled
  # and produced (3/5)^5 ≈ 7.78% rejection rate from Scaleway. min_special=4
  # keeps entropy high without sacrificing the guarantee.
  min_special = 4

  lifecycle {
    ignore_changes = [override_special, min_numeric, min_special, length]
  }
}

locals {
  password = random_password.this[0].result
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

  lifecycle {
    # The matching scaleway_secret_version.this below has ignore_changes=[data]
    # so the secret bag pins the live password across refresh. Without the same
    # treatment here, every plan that rebuilds random_password.this (e.g. fork
    # cutovers from credentials_preserve mode) would rotate the live RDB user
    # password while the secret bag stays on the old value — apps pull the old
    # creds and fail to authenticate. Rotate by tainting random_password.this
    # and applying both this resource and the secret_version together.
    ignore_changes = [password]
  }
}

resource "scaleway_rdb_privilege" "this" {
  user_name     = scaleway_rdb_user.this.name
  database_name = scaleway_rdb_database.this.name
  instance_id   = var.instance_id
  permission    = var.permission
}

resource "scaleway_secret" "this" {
  count = 1

  name        = "postgres-${var.database_name}-credentials"
  description = "Database credentials for ${var.database_name}"
  tags        = distinct(concat(var.tags, ["postgres"]))
  type        = "database_credentials"
}

resource "scaleway_secret_version" "this" {
  count = 1

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
