variable "instance_name" {
  description = "Name of the RDB instance"
  type        = string
}

variable "database_engine" {
  description = "Engine version (e.g., PostgreSQL-16)"
  type        = string
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
  description = "List of databases to create"
  type        = list(string)
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
