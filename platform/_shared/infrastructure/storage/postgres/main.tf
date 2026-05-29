locals {
  dbs   = var.databases
  users = concat([var.psql_default_user], local.dbs)
}

resource "scaleway_rdb_instance" "this" {
  name               = var.instance_name
  node_type          = var.node_type
  engine             = var.database_engine
  is_ha_cluster      = var.high_availability
  user_name          = var.psql_default_user
  password           = local.user_passwords[var.psql_default_user]
  encryption_at_rest = true

  backup_same_region        = var.backup_same_region
  backup_schedule_frequency = var.backup_schedule_frequency
  backup_schedule_retention = var.backup_schedule_retention

  volume_size_in_gb = var.volume_size_in_gb
  volume_type       = var.volume_type

  settings = {
    "effective_cache_size"            = "1300"
    "maintenance_work_mem"            = "150"
    "max_connections"                 = var.max_connections
    "max_parallel_workers"            = "2"
    "max_parallel_workers_per_gather" = "2"
    "work_mem"                        = "4"
  }

  tags = var.tags

  private_network {
    enable_ipam = var.network.enable_ipam
    pn_id       = var.network.pn_id
    port        = var.network.port
  }

  lifecycle {
    # password is ignored as defence-in-depth: a stale plan must not trigger
    # an UpdatePassword API call against an imported instance.
    ignore_changes = [
      private_network[0].enable_ipam,
      password,
    ]
  }
}

resource "scaleway_rdb_database" "dbs" {
  for_each    = toset(local.dbs)
  name        = each.value
  instance_id = scaleway_rdb_instance.this.id
  # scaleway_rdb_instance returns once Scaleway reports the instance as
  # "ready" — no separate wait needed. (The previous time_sleep wedged in
  # one staging run for hours; if a flake reappears, prefer an active poll
  # via local-exec over a fixed sleep.)
  depends_on = [scaleway_rdb_instance.this]
}

resource "random_password" "db_passwords" {
  for_each         = toset(local.users)
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
  user_passwords = {
    for u in local.users : u => random_password.db_passwords[u].result
  }
}

resource "scaleway_rdb_user" "users" {
  for_each    = toset(local.dbs)
  name        = each.value
  password    = local.user_passwords[each.value]
  is_admin    = contains(var.admin_databases, each.value)
  instance_id = scaleway_rdb_instance.this.id

  depends_on = [scaleway_rdb_database.dbs]
}

resource "scaleway_secret" "admin_credentials" {
  count = 1

  name        = "${var.instance_name}-admin-credentials"
  description = "Admin credentials for the ${var.instance_name} PostgreSQL instance. Used by downstream modules to provision per-app databases."
  tags        = distinct(concat(var.tags, ["postgres", "admin"]))
  type        = "database_credentials"
}

resource "scaleway_secret_version" "admin_credentials" {
  count = 1

  secret_id = scaleway_secret.admin_credentials[0].id
  # Schema is enforced because type=database_credentials. The dbname is the
  # default 'postgres' database; admin connects there to manage other DBs.
  data = jsonencode({
    engine   = var.database_engine
    dbname   = "postgres"
    username = var.psql_default_user
    password = local.user_passwords[var.psql_default_user]
    host     = scaleway_rdb_instance.this.private_network[0].ip
    port     = tostring(scaleway_rdb_instance.this.private_network[0].port)
  })
  description = "Admin credentials for ${var.instance_name}."

  lifecycle {
    # Scaleway's API doesn't return secret values on read; after `terraform
    # import` the refreshed `data` is null and re-render looks like a
    # forces_replacement diff — destroying admin creds in-flight. Lock the
    # version. Rotate by tainting this resource.
    ignore_changes = [data]
  }
}

resource "scaleway_rdb_privilege" "privileges" {
  for_each = toset(local.dbs)

  user_name     = scaleway_rdb_user.users[each.value].name
  database_name = scaleway_rdb_database.dbs[each.value].name
  instance_id   = scaleway_rdb_instance.this.id
  permission    = "all"
}

resource "scaleway_secret" "db_credentials" {
  for_each    = toset(local.dbs)
  name        = "postgres-${each.value}-credentials"
  description = "Database credentials for ${each.value}"
  tags        = ["postgres"]
  type        = "database_credentials"
}

resource "scaleway_secret_version" "db_credentials" {
  for_each  = toset(local.dbs)
  secret_id = scaleway_secret.db_credentials[each.value].id
  data = jsonencode({
    dbname   = each.value
    engine   = var.database_engine
    username = scaleway_rdb_user.users[each.value].name
    password = local.user_passwords[each.value]
    host     = scaleway_rdb_instance.this.private_network[0].ip
    port     = tostring(scaleway_rdb_instance.this.private_network[0].port)
  })
  description = "Database credentials for ${each.value}"

  lifecycle {
    # See admin_credentials lifecycle: API-on-read returns null so re-render
    # forces replacement on imported secrets, dropping every app's DB creds.
    ignore_changes = [data]
  }
}

output "database_credentials_secrets" {
  value       = { for k, v in scaleway_secret.db_credentials : k => { id = v.id, name = v.name } }
  description = "Per-database Scaleway secret handles {id, name}."
}

output "database_passwords" {
  value       = { for u in local.users : u => local.user_passwords[u] }
  description = "Passwords used for databases."
  sensitive   = true
}

output "instance_id" {
  value       = scaleway_rdb_instance.this.id
  description = "ID of the created RDB instance"
}

output "endpoint" {
  description = "Private-network endpoint for the instance. Use these to provision per-app databases from other modules."
  value = {
    ip          = scaleway_rdb_instance.this.private_network[0].ip
    port        = tonumber(scaleway_rdb_instance.this.private_network[0].port)
    endpoint_id = scaleway_rdb_instance.this.private_network[0].endpoint_id
  }
}

output "admin_user" {
  description = "Admin username for the RDB instance."
  value       = var.psql_default_user
}

output "admin_password" {
  description = "Admin password for the RDB instance. Prefer reading from admin_credentials_secret_id."
  value       = local.user_passwords[var.psql_default_user]
  sensitive   = true
}

output "admin_credentials_secret_id" {
  description = "Scaleway Secret Manager ID holding admin credentials (engine, username, password, host, port)."
  value       = scaleway_secret.admin_credentials[0].id
}
