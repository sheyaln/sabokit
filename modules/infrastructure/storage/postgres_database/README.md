# postgres_database

Provisions one database + matching user + generated password + Scaleway secret inside an existing managed PostgreSQL instance. App bundles call this to own their own database without each baking in five raw resources.

## Usage

```hcl
module "outline_db" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/storage/postgres_database?ref=v1.0.0"

  instance_id       = var.base.scaleway.postgres_instance_id
  instance_endpoint = var.base.scaleway.postgres_endpoint
  database_name     = "outline"
  engine            = "PostgreSQL-16"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `instance_id` | `string` | — | ID of the managed PostgreSQL instance to provision the database in (typically `base.scaleway.postgres_instance_id`). |
| `instance_endpoint` | `object({ ip, port })` | — | Private-network endpoint of the instance (typically `base.scaleway.postgres_endpoint`). Object with `ip` and `port`. |
| `database_name` | `string` | — | Database name to create. Used as the secret prefix too. |
| `user_name` | `string` | `null` | Database user name. Defaults to `database_name` when null. |
| `is_admin` | `bool` | `false` | Whether the database user should have admin privileges (required for apps that `CREATE DATABASE` at runtime, e.g. multi-tenant apps). |
| `permission` | `string` | `"all"` | Privilege level on the database. `all` is the default and right for almost every app. |
| `engine` | `string` | — | Engine identifier copied into the secret. Should match the instance engine, e.g. `PostgreSQL-16`. |
| `tags` | `list(string)` | `[]` | Extra tags applied to the Scaleway secret. |

## Outputs

| Name | Description |
|------|-------------|
| `database_name` | Name of the created database. |
| `user_name` | Name of the created database user. |
| `password` | Generated password for the user. Prefer reading from `secret_id`. |
| `secret_id` | Scaleway secret holding `{dbname, engine, username, password, host, port}`. |
