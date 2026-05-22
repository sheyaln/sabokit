locals {
  dbs   = var.databases
  users = concat([var.psql_default_user], local.dbs)
}

resource "scaleway_rdb_instance" "this" {
  name               = var.instance_name
  node_type          = "db-dev-s"
  engine             = var.database_engine
  is_ha_cluster      = var.high_availability
  user_name          = var.psql_default_user
  password           = random_password.db_passwords[var.psql_default_user].result
  encryption_at_rest = true

  backup_same_region        = var.backup_same_region
  backup_schedule_frequency = var.backup_schedule_frequency
  backup_schedule_retention = var.backup_schedule_retention

  volume_size_in_gb = var.volume_size_in_gb
  volume_type       = "sbs_5k"

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
    ignore_changes = [
      private_network[0].enable_ipam,
    ]
  }
}

resource "time_sleep" "wait_for_rdb_ready" {
  depends_on      = [scaleway_rdb_instance.this]
  create_duration = "180s"
}

resource "scaleway_rdb_database" "dbs" {
  for_each    = toset(local.dbs)
  name        = each.value
  instance_id = scaleway_rdb_instance.this.id
  depends_on  = [time_sleep.wait_for_rdb_ready]
}

resource "random_password" "db_passwords" {
  for_each         = toset(local.users)
  length           = 32
  special          = true
  override_special = "!@+=:,._-"
  min_numeric      = 1

  lifecycle {
    ignore_changes = [override_special, min_numeric]
  }
}

resource "scaleway_rdb_user" "users" {
  for_each    = toset(local.dbs)
  name        = each.value
  password    = random_password.db_passwords[each.key].result
  is_admin    = contains(var.admin_databases, each.value)
  instance_id = scaleway_rdb_instance.this.id

  depends_on = [scaleway_rdb_database.dbs]
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
    password = random_password.db_passwords[each.value].result
    host     = scaleway_rdb_instance.this.private_network[0].ip
    port     = tostring(scaleway_rdb_instance.this.private_network[0].port)
  })
  description = "Database credentials for ${each.value}"
}

output "database_credentials_secrets" {
  value       = scaleway_secret.db_credentials
  description = "Database credentials secrets for all databases"
}

output "database_passwords" {
  value       = random_password.db_passwords
  description = "Random passwords generated for databases"
}

output "instance_id" {
  value       = scaleway_rdb_instance.this.id
  description = "ID of the created RDB instance"
}
