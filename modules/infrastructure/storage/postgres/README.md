# postgres

Provisions a Scaleway managed PostgreSQL instance attached to a private network, with encryption at rest, backup schedule, and an admin user. Optionally pre-creates a set of databases (each with a matching user, generated password, and Scaleway secret) via the `databases` input.

Apps that own their own databases should pass `databases = []` and use the `postgres_database` helper (or raw `scaleway_rdb_database` resources) against this instance's `endpoint` output. The admin credentials are exported as a Scaleway secret ID rather than a Terraform output where practical.

## Usage

```hcl
module "postgres" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/storage/postgres?ref=v2.1.0"

  instance_name     = "fc-prod-pg"
  database_engine   = "PostgreSQL-16"
  node_type         = "db-pro2-s"
  volume_size_in_gb = 50
  psql_default_user = "admin"

  network = {
    enable_ipam = true
    ip_net      = ""
    pn_id       = module.private_network.id
    port        = 5432
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `instance_name` | `string` | — | Name of the RDB instance. |
| `database_engine` | `string` | — | Engine version (e.g., `PostgreSQL-16`). |
| `node_type` | `string` | `"db-dev-s"` | Scaleway RDB node type. `db-dev-s` is the smallest (2 vCPU / 2 GB RAM). |
| `volume_type` | `string` | `"sbs_5k"` | Storage volume type. `sbs_5k` is the default block-storage; `bssd` is the legacy local SSD. |
| `psql_default_user` | `string` | — | Default admin user name. |
| `high_availability` | `bool` | `false` | Whether to create an HA cluster. |
| `backup_same_region` | `bool` | `true` | Store backups in same region. |
| `backup_schedule_frequency` | `number` | `24` | Backup frequency in hours. |
| `backup_schedule_retention` | `number` | `7` | Number of backups to retain. |
| `volume_size_in_gb` | `number` | — | Volume size in GB (min 10). |
| `max_connections` | `number` | `100` | Max PostgreSQL connections. |
| `network` | `object({ enable_ipam, ip_net, pn_id, port })` | — | Private network configuration. |
| `databases` | `list(string)` | `[]` | Optional list of databases to provision in this instance. Each database also gets a same-named user, a 32-char password, and a Scaleway secret with credentials. Apps that own their own databases should pass `[]` here and provision them via the `postgres_database` helper or raw `scaleway_rdb_database` resources against this instance's endpoint. |
| `admin_databases` | `list(string)` | `[]` | Databases whose users require admin privileges (e.g. `CREATE DATABASE`). Must be a subset of `var.databases`. |
| `tags` | `list(string)` | `[]` | Instance tags. |
| `prevent_destroy_db_users` | `bool` | `true` | If true, prevents Terraform from destroying DB users managed by this module. |

## Outputs

| Name | Description |
|------|-------------|
| `database_credentials_secrets` | Database credentials secrets for all databases. |
| `database_passwords` | Random passwords generated for databases. |
| `instance_id` | ID of the created RDB instance. |
| `endpoint` | Private-network endpoint for the instance. Use these to provision per-app databases from other modules. |
| `admin_user` | Admin username for the RDB instance. |
| `admin_password` | Admin password for the RDB instance. Prefer reading from `admin_credentials_secret_id`. |
| `admin_credentials_secret_id` | Scaleway Secret Manager ID holding admin credentials (engine, username, password, host, port). |
