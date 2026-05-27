# ── Contract inputs ─────────────────────────────────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\"."
  type        = any
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Loki instance runs on. Typically your monitoring host."
  type        = string
  default     = "management"
}

# ── Loki-specific inputs ────────────────────────────────────────────────────

variable "image" {
  description = "Loki Docker image (without tag)."
  type        = string
  default     = "grafana/loki"
}

variable "image_tag" {
  description = "Loki Docker image tag. Pin in production."
  type        = string
  default     = "latest"
}

variable "retention" {
  description = "Log retention window. Loki schema duration syntax (744h = ~31d)."
  type        = string
  default     = "744h"
}

variable "ingestion_rate_mb" {
  description = "Per-stream ingestion rate ceiling, MB/s. Bump if log-shipping agents are hitting the limit."
  type        = number
  default     = 10
}

variable "ingestion_burst_size_mb" {
  description = "Burst tolerance above ingestion_rate_mb."
  type        = number
  default     = 20
}

variable "private_ip_bind" {
  description = "Optional host private IP to bind Loki's port 3100 to. Empty = 127.0.0.1 only. Set to a private-network IP to let remote Alloy/Promtail agents push logs."
  type        = string
  default     = ""
}

variable "memory_limit" {
  description = "Container memory ceiling."
  type        = string
  default     = "1G"
}

variable "memory_reservation" {
  description = "Container memory reservation."
  type        = string
  default     = "256M"
}

variable "cpu_limit" {
  description = "Container CPU ceiling."
  type        = string
  default     = "1.0"
}

variable "cpu_reservation" {
  description = "Container CPU reservation."
  type        = string
  default     = "0.25"
}

variable "timezone" {
  description = "IANA timezone for the container (log timestamps)."
  type        = string
  default     = "UTC"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle restarts Loki when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle backs up Loki's chunks + index. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/loki`. Chunks + index live in the named volume `loki_loki-data`."
  type        = list(string)
  default     = ["/backup-sources/docker-volumes/loki_loki-data/_data"]
}

variable "backup_schedule_cron" {
  description = "Backrest cron (6-field). Default 02:00 UTC daily."
  type        = string
  default     = "0 0 2 * * *"
}

variable "backup_retention" {
  description = "Restic retention policy."
  type = object({
    hourly  = optional(number)
    daily   = optional(number)
    weekly  = optional(number)
    monthly = optional(number)
    yearly  = optional(number)
  })
  default = {
    daily   = 7
    weekly  = 4
    monthly = 12
    yearly  = 1
  }
}

variable "extra_env_vars" {
  description = "Map of KEY → value rendered into the container .env after first-class vars. Use for env-driven feature flags / third-party integrations / debug toggles not exposed first-class on the bundle."
  type        = map(string)
  default     = {}
}
