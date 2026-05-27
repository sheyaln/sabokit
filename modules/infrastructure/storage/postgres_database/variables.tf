variable "instance_id" {
  description = "ID of the managed PostgreSQL instance to provision the database in (typically base.scaleway.postgres_instance_id)."
  type        = string
}

variable "instance_endpoint" {
  description = "Private-network endpoint of the instance (typically base.scaleway.postgres_endpoint). Object with ip and port."
  type = object({
    ip   = string
    port = number
  })
}

variable "database_name" {
  description = "Database name to create. Used as the secret prefix too."
  type        = string
}

variable "user_name" {
  description = "Database user name. Defaults to database_name when null."
  type        = string
  default     = null
}

variable "is_admin" {
  description = "Whether the database user should have admin privileges (required for apps that CREATE DATABASE at runtime, e.g. multi-tenant apps)."
  type        = bool
  default     = false
}

variable "permission" {
  description = "Privilege level on the database. 'all' is the default and right for almost every app."
  type        = string
  default     = "all"
}

variable "engine" {
  description = "Engine identifier copied into the secret. Should match the instance engine, e.g. 'PostgreSQL-16'."
  type        = string
}

variable "tags" {
  description = "Extra tags applied to the Scaleway secret."
  type        = list(string)
  default     = []
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, skips `random_password` generation and reads the existing user password from the live `postgres-<database_name>-credentials` bag via a data source. Drop the flag after cutover; short-lived knob, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "credentials_preserve_source" {
  description = "Greenfield-to-v3 cutover support. Sibling to `credentials_preserve` (gated separately, both null/false by default). When non-null AND `credentials_preserve = false`, this map supplies the canonical key `password` directly to the bag on first apply instead of pulling it from a pre-populated one. Schema: `{ password = string }`. `random_password.this` still gets generated for state stability; the supplied password shadows it at the locals layer. After the first apply, `ignore_changes = [data]` on the bag version keeps the value pinned and the variable can be dropped (or flipped to `credentials_preserve = true`)."
  type        = map(string)
  default     = null
  sensitive   = true
}
