# ── Scaleway scope ──────────────────────────────────────────────────────────

variable "scaleway_project_id" {
  description = "Scaleway project ID. Everything this module creates lands in this project."
  type        = string
}

variable "scaleway_region" {
  description = "Scaleway region for regional resources (RDB, object storage, secrets)."
  type        = string
  default     = "fr-par"
}

variable "scaleway_zone" {
  description = "Scaleway zone for zonal resources (compute instances)."
  type        = string
  default     = "fr-par-1"
}

# ── Naming / tagging ────────────────────────────────────────────────────────

variable "org_slug" {
  description = "Short URL-safe slug used to name resources (e.g. \"acme\", \"fc\"). Keep it short — appears in instance names, bucket names, secret names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.org_slug))
    error_message = "org_slug must be 2-16 lowercase letters/digits/hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Short environment label used as a name suffix (\"prod\", \"staging\", \"dev\"). Resources are not isolated by this — it's just naming."
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = list(string)
  default     = []
}

# ── Domains (pass-through to outputs; not used by Scaleway directly) ────────

variable "base_domain" {
  description = "Primary apps domain (e.g. \"example.org\"). Apps use this in their hostname inputs."
  type        = string
}

variable "mgmt_domain" {
  description = "Management apps domain (e.g. \"ops.example.org\"). Set equal to base_domain when there's no separate management host."
  type        = string
  default     = null
}

variable "gateway_domain" {
  description = "Hostname of the Authentik gateway (e.g. \"auth.example.org\"). Used by base/authentik/."
  type        = string
  default     = null
}

# ── Network ─────────────────────────────────────────────────────────────────

variable "private_network_subnet" {
  description = "Explicit IPv4 CIDR for the private network. null = Scaleway auto-assigns. Pass an explicit CIDR (e.g. \"10.0.0.0/22\") when running managed PostgreSQL, which needs a /22 with IPAM."
  type        = string
  default     = null
}

# ── Security groups ─────────────────────────────────────────────────────────

variable "default_security_group_extra_inbound_rules" {
  description = "Additional inbound rules appended to the default security group beyond SSH/HTTP/HTTPS. Same shape as modules/infrastructure/security_group inbound_rules."
  type = list(object({
    protocol   = string
    port       = optional(number)
    port_range = optional(string)
    ip_range   = optional(string, "0.0.0.0/0")
  }))
  default = []
}

# ── Compute hosts ───────────────────────────────────────────────────────────

variable "compute_hosts" {
  description = "Compute hosts to provision, keyed by short host name. All hosts get the default security group unless a host overrides security_group_id."
  type = map(object({
    instance_type = string
    image         = optional(string, "ubuntu_jammy")
    disk_size     = optional(number, 30)
    disk_type     = optional(string, "sbs_volume")
    role          = string
    ansible_group = string
    # Extra Ansible groups this host belongs to. Lets a single-VM staging
    # setup put one host in [apps], [identity], and a custom env group at
    # the same time. Primary group = ansible_group; extras append.
    ansible_groups    = optional(list(string), [])
    protected         = optional(bool, false)
    user_data         = optional(map(string), {})
    security_group_id = optional(string, null)
    tags              = optional(list(string), [])
  }))
  default = {}
}

# ── Gateway DNS ─────────────────────────────────────────────────────────────

variable "manage_gateway_dns" {
  description = "Whether to create the gateway A record in Scaleway DNS as part of this module's apply. When true (default), the record points at the identity host's public IP and is provisioned in the same apply as the compute host — DNS is correct by the time Traefik requests an LE cert. Set false if you manage gateway DNS out-of-band (Cloudflare, Route53, manual)."
  type        = bool
  default     = true
}

variable "gateway_compute_host_key" {
  description = "Optional explicit key in var.compute_hosts whose public IP becomes the gateway DNS record. Null (default) picks the first host with \"identity\" in its ansible_groups, then any host with role = \"identity\", then the first compute host (lexicographic). Multi-host prod usually sets this explicitly."
  type        = string
  default     = null
}

variable "gateway_dns_ttl" {
  description = "TTL (seconds) on the gateway A record. Low default (60) makes IP changes propagate fast across re-provisions."
  type        = number
  default     = 60
}

# ── Managed PostgreSQL ──────────────────────────────────────────────────────

variable "postgres_enabled" {
  description = "Whether to provision a shared managed PostgreSQL instance. Apps create their own databases inside it via modules/infrastructure/storage/postgres_database."
  type        = bool
  default     = true
}

variable "postgres_engine" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "PostgreSQL-16"
}

variable "postgres_node_type" {
  description = "Scaleway RDB node type."
  type        = string
  default     = "db-dev-s"
}

variable "postgres_volume_size_in_gb" {
  description = "Postgres volume size in GB (minimum 10)."
  type        = number
  default     = 10
}

variable "postgres_high_availability" {
  description = "Whether to provision an HA Postgres cluster (doubles cost)."
  type        = bool
  default     = false
}

variable "postgres_max_connections" {
  description = "Max simultaneous Postgres connections allowed across all apps."
  type        = number
  default     = 200
}

variable "postgres_backup_schedule_frequency_hours" {
  description = "Hours between automated Postgres backups."
  type        = number
  default     = 24
}

variable "postgres_backup_schedule_retention_days" {
  description = "Days of automated Postgres backups to retain."
  type        = number
  default     = 7
}
