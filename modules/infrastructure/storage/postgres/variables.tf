variable "instance_name" {
  description = "Name of the RDB instance"
  type        = string
}

variable "database_engine" {
  description = "Engine version (e.g., PostgreSQL-16)"
  type        = string
}

variable "node_type" {
  description = "Scaleway RDB node type. See https://www.scaleway.com/en/database/ for available types. 'db-dev-s' is the smallest (2 vCPU / 2 GB RAM)."
  type        = string
  default     = "db-dev-s"
}

variable "volume_type" {
  description = "Storage volume type. 'sbs_5k' is the default block-storage; 'bssd' is the legacy local SSD."
  type        = string
  default     = "sbs_5k"
}

variable "psql_default_user" {
  description = "Default admin user name"
  type        = string
}

variable "high_availability" {
  description = "Whether to create an HA cluster"
  type        = bool
  default     = false
}

variable "backup_same_region" {
  description = "Store backups in same region"
  type        = bool
  default     = true
}

variable "backup_schedule_frequency" {
  description = "Backup frequency in hours"
  type        = number
  default     = 24
}

variable "backup_schedule_retention" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

variable "volume_size_in_gb" {
  description = "Volume size in GB (min 10)"
  type        = number
}

variable "max_connections" {
  description = "Max PostgreSQL connections"
  type        = number
  default     = 100
}

variable "network" {
  description = "Private network configuration"
  type = object({
    enable_ipam = bool
    ip_net      = string
    pn_id       = string
    port        = number
  })
}

variable "databases" {
  description = "Optional list of databases to provision in this instance. Each database also gets a same-named user, a 32-char password, and a Scaleway secret with credentials. Apps that own their own databases should pass [] here and provision them via the postgres_database helper or raw scaleway_rdb_database resources against this instance's endpoint."
  type        = list(string)
  default     = []
}

variable "admin_databases" {
  description = "Databases whose users require admin privileges (e.g. CREATE DATABASE). Must be a subset of var.databases."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Instance tags"
  type        = list(string)
  default     = []
}

variable "prevent_destroy_db_users" {
  description = "If true, prevents Terraform from destroying DB users managed by this module"
  type        = bool
  default     = true
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, skips `random_password` generation for every user managed by this module and reads each user's existing password from the live `<instance_name>-admin-credentials` (admin) and `postgres-<dbname>-credentials` (per-db) bags via data sources. Drop the flag after cutover; short-lived knob, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "credentials_preserve_source" {
  description = "Greenfield-to-v3 cutover support. Sibling to `credentials_preserve` (gated separately, both null/false by default). When non-null AND `credentials_preserve = false`, this object supplies admin + per-database canonical passwords directly to the Scaleway bags on first apply, instead of pulling them from pre-populated bags. Shape: `{ admin = string, databases = map(string) }` where `admin` is the admin password and `databases` is a `<dbname> => password` map. Keys not present in either field fall back to the module's generated `random_password` value, so partial-supply is allowed. After the first apply, `ignore_changes = [data]` on the bag versions keeps the values pinned and the variable can be dropped (or flipped to `credentials_preserve = true`)."
  type = object({
    admin     = optional(string)
    databases = optional(map(string), {})
  })
  default   = null
  sensitive = true
}
