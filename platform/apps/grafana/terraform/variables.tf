# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\"."
  type        = any
}

variable "hostname" {
  description = "Full hostname Grafana is served at (e.g. \"grafana.example.org\")."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Operations"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"admin\" — Grafana exposes alerting + data sources, treat as ops-only by default."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed beyond access_level. Keys must be static strings."
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Grafana's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Grafana instance runs on. Typically the same as your prometheus + loki host."
  type        = string
  default     = "management"
}

# ── Grafana-specific inputs ─────────────────────────────────────────────────

variable "image" {
  description = "Grafana Docker image (without tag)."
  type        = string
  default     = "grafana/grafana"
}

variable "image_tag" {
  description = "Grafana Docker image tag. Pin in production."
  type        = string
  default     = "latest"
}

variable "admin_username" {
  description = "Bootstrap admin username. OIDC users sign in separately; this is the break-glass account."
  type        = string
  default     = "admin"
}

variable "plugins" {
  description = "List of plugins to preinstall via GF_PLUGINS_PREINSTALL. Comma-joined into the env var at render time."
  type        = list(string)
  default     = []
}

variable "oidc_admin_group" {
  description = "Authentik group name whose members are mapped to Grafana's Admin role."
  type        = string
  default     = "admin"
}

variable "oidc_editor_group" {
  description = "Authentik group name whose members are mapped to Grafana's Editor role."
  type        = string
  default     = "manager"
}

variable "prometheus_url" {
  description = "URL Grafana uses to reach Prometheus. Default `http://prometheus:9090` works when both bundles share the `monitoring_internal` docker network."
  type        = string
  default     = "http://prometheus:9090"
}

variable "loki_url" {
  description = "URL Grafana uses to reach Loki. Default `http://loki:3100` works for shared-network deployments."
  type        = string
  default     = "http://loki:3100"
}

variable "prometheus_scrape_interval" {
  description = "Scrape interval Grafana's Prometheus datasource expects. Should match the prometheus bundle's global.scrape_interval (default 30s)."
  type        = string
  default     = "30s"
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
  default     = "0.1"
}

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle auto-pulls newer Grafana images. Default FALSE — Grafana plugins can pin to specific Grafana versions; let Ansible drive bumps."
  type        = bool
  default     = false
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle restarts Grafana when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle backs up Grafana's SQLite + dashboards. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths. Grafana's data dir is the named volume `grafana_grafana-data`."
  type        = list(string)
  default     = ["/backup-sources/docker-volumes/grafana_grafana-data/_data"]
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
