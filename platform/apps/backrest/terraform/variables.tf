# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Apps consume { scaleway, authentik, compute, domains } from this. Shape documented in /ARCHITECTURE.md (\"What base/ outputs\")."
  type        = any
}

variable "hostname" {
  description = "Full hostname this Backrest instance is served at (e.g. \"backup.tools.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Operations"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"backrest-icon.png\")."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"admin\" — Backrest exposes raw filesystem paths and restore controls, treat it as ops-only."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access this Backrest instance beyond access_level. Map of role-name → group ID; keys MUST be static strings so for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Backrest's /metrics endpoint and log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Backrest instance deploys to. Each host being backed up should run its own instance pinned to that host's key."
  type        = string
}

# ── Backrest-specific inputs ────────────────────────────────────────────────

variable "instance_name" {
  description = "Per-instance name suffix. Backrest is typically deployed once per host being backed up; this string namespaces every cloud resource (S3 bucket, IAM principal, secret, Authentik app/group) so multiple instances under the same base do not collide. Lowercase letters, digits and hyphens only — used directly in resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.instance_name))
    error_message = "instance_name must be 3-32 chars, lowercase letters/digits/hyphens, not start or end with a hyphen."
  }
}

variable "image_tag" {
  description = "Backrest Docker image tag. Pin in production; the upstream `latest` tag moves frequently."
  type        = string
  default     = "latest"
}

variable "backup_plans" {
  description = "Backup plans this instance will run. Each entry becomes an entry in Backrest's config.json `plans[]` array. `id` must be unique within the instance. `paths` are paths INSIDE the container; default `backup_sources` mount `/opt` and `/var/lib/docker/volumes` from the host read-only, so a typical path is \"/backup-sources/opt/<app>\" or \"/backup-sources/docker-volumes/<volume>\"."
  type = list(object({
    id       = string
    paths    = list(string)
    excludes = optional(list(string), [])
    schedule = object({
      cron = string
    })
    retention = object({
      hourly  = optional(number)
      daily   = optional(number)
      weekly  = optional(number)
      monthly = optional(number)
      yearly  = optional(number)
    })
  }))
  default = []

  validation {
    condition     = length(var.backup_plans) == length(distinct([for p in var.backup_plans : p.id]))
    error_message = "backup_plans entries must have unique `id` values within the instance."
  }
}

variable "backup_sources" {
  description = "Host paths bind-mounted read-only into the container under /backup-sources/<key>. The default mounts /opt (apps' bind-mount data) and /var/lib/docker/volumes (named-volume data) which together cover everything sabokit apps persist. Extend (don't replace) when an app stores state outside these trees."
  type        = map(string)
  default = {
    "opt"            = "/opt"
    "docker-volumes" = "/var/lib/docker/volumes"
  }
}

variable "restic_prune_max_frequency_days" {
  description = "Minimum days between restic prune runs. Lower = more aggressive cleanup, higher I/O cost; higher = cheaper, more cold storage."
  type        = number
  default     = 7
}

variable "restic_check_max_frequency_days" {
  description = "Minimum days between restic repository integrity checks."
  type        = number
  default     = 30
}

variable "restic_check_read_data_subset_percent" {
  description = "Percentage of pack files restic reads back when running a scheduled check. 0 = metadata only (fast); higher catches bitrot but is bandwidth-heavy."
  type        = number
  default     = 5
}
