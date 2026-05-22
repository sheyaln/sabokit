module "postgres" {
  count  = var.postgres_enabled ? 1 : 0
  source = "../../modules/infrastructure/storage/postgres"

  instance_name     = local.postgres_instance_name
  database_engine   = var.postgres_engine
  node_type         = var.postgres_node_type
  psql_default_user = local.postgres_admin_user

  high_availability         = var.postgres_high_availability
  backup_same_region        = true
  backup_schedule_frequency = var.postgres_backup_schedule_frequency_hours
  backup_schedule_retention = var.postgres_backup_schedule_retention_days

  volume_size_in_gb = var.postgres_volume_size_in_gb
  max_connections   = var.postgres_max_connections

  databases = []

  network = {
    enable_ipam = true
    ip_net      = var.private_network_subnet
    pn_id       = module.network.id
    port        = 5432
  }

  tags = concat(local.base_tags, ["postgres"])
}
