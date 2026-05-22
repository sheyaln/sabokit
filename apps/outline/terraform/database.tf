module "database" {
  source = "../../../modules/infrastructure/storage/postgres_database"
  count  = var.enabled ? 1 : 0

  instance_id       = var.base.scaleway.postgres_instance_id
  instance_endpoint = var.base.scaleway.postgres_endpoint
  database_name     = local.slug
  engine            = var.base.scaleway.postgres_engine
  tags              = [local.slug]
}
