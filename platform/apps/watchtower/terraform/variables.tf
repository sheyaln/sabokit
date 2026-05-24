# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Watchtower only consumes the deployment_host_key target; the full base object is taken for shape parity with other bundles."
  type        = any
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Watchtower instance runs on. Watchtower is one-per-host: a single container watches every docker container on that host and pulls newer image versions of any container whose label opts in. Instantiate this module once per host you want auto-updates on."
  type        = string
  default     = "apps"
}

# ── Watchtower-specific inputs ──────────────────────────────────────────────

variable "image" {
  description = "Watchtower Docker image (without tag)."
  type        = string
  default     = "containrrr/watchtower"
}

variable "image_tag" {
  description = "Watchtower Docker image tag."
  type        = string
  default     = "latest"
}

variable "schedule" {
  description = "Cron expression governing how often Watchtower polls for new images. Six-field cron (seconds first). Default is daily at 04:00 UTC, deliberately offset from backrest (02:00) and app-bundle nightly windows (typically 02:00 too) to avoid restart storms competing with backups."
  type        = string
  default     = "0 0 4 * * *"
}

variable "label_enable" {
  description = "If true (default), Watchtower only updates containers that have the `com.centurylinklabs.watchtower.enable=true` label. App bundles set this label from their own `auto_update_enabled` knob. Flip to false to make Watchtower watch every container on the host (much more permissive — most ops shops don't want this)."
  type        = bool
  default     = true
}

variable "scope" {
  description = "Optional scope name. When non-empty, Watchtower only touches containers also carrying `com.centurylinklabs.watchtower.scope=<value>`. Useful when running multiple Watchtower instances on the same host with different schedules (e.g. one for staging, one for prod). Empty disables the scope filter."
  type        = string
  default     = ""
}

variable "cleanup" {
  description = "Whether Watchtower removes old image layers after a successful update. Default true — keeps disk from filling up over months of updates."
  type        = bool
  default     = true
}

variable "rolling_restart" {
  description = "Restart containers one at a time instead of all at once. Reduces availability dip during multi-container app updates (e.g. nextcloud has 5 containers). No downside for single-container apps."
  type        = bool
  default     = true
}

variable "include_stopped" {
  description = "Also update stopped containers. Default false — most operators don't want a manually-stopped container starting back up just because a new image landed."
  type        = bool
  default     = false
}

variable "timezone" {
  description = "IANA timezone for the container. Affects Watchtower's log timestamps + cron expression interpretation."
  type        = string
  default     = "UTC"
}

variable "notifications_slack_webhook" {
  description = "Optional Slack incoming-webhook URL. When non-empty, Watchtower posts a summary to Slack after each update run. Empty disables notifications."
  type        = string
  default     = ""
  sensitive   = true
}
