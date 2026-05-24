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
  description = "Which host the ProtonMail Bridge container runs on. Must be reachable from every host with apps that FETCH mail through it."
  type        = string
  default     = "management"
}

# ── Bridge-specific inputs ──────────────────────────────────────────────────
#
# IMAP-only. SMTP for sabokit is handled by Scaleway TEM at the
# `platform/base/` tier (the `smtp-config` secret base writes is what apps
# send through). This bundle exists for apps that need to RECEIVE / FETCH
# mail from a ProtonMail account — typically n8n workflows polling an inbox.

variable "image" {
  description = "Bridge image. Default `shenxn/protonmail-bridge` is the community prebuilt."
  type        = string
  default     = "shenxn/protonmail-bridge"
}

variable "image_tag" {
  description = "Bridge image tag."
  type        = string
  default     = "latest"
}

variable "imap_username" {
  description = "ProtonMail account email used for the bridge login. Apps fetching mail use this as their IMAP username."
  type        = string
}

variable "bridge_login_secret_id" {
  description = "Scaleway secret ID holding the bridge's SERVICE-SPECIFIC password (NOT the ProtonMail account password). Consumer obtains it once via ProtonMail Settings → Bridge → generate new password, stores it in Scaleway out-of-band, then passes the secret ID here. The bundle reads it to populate the imap-config secret apps consume."
  type        = string
}

variable "imap_config_secret_name" {
  description = "Name of the Scaleway secret this bundle writes for apps to consume IMAP credentials. Default `imap-config` matches the well-known name. Override only when running multiple bridge instances per env (rare; you'd also need to override each consuming app's `imap_secret_name`)."
  type        = string
  default     = "imap-config"
}

variable "memory_limit" {
  description = "Container memory ceiling."
  type        = string
  default     = "256M"
}

variable "memory_reservation" {
  description = "Container memory reservation."
  type        = string
  default     = "64M"
}

variable "cpu_limit" {
  description = "Container CPU ceiling."
  type        = string
  default     = "0.5"
}

variable "cpu_reservation" {
  description = "Container CPU reservation."
  type        = string
  default     = "0.05"
}

variable "timezone" {
  description = "IANA timezone for the container."
  type        = string
  default     = "UTC"
}

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle auto-pulls newer Bridge image versions. Default FALSE — bridge schema migrations between minor versions need the manual re-login flow."
  type        = bool
  default     = false
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle restarts the bridge container on healthcheck failure. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle backs up the bridge's data volume (contains login state + cached credentials)."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths. Bridge data lives in the named volume `protonmail-bridge_protonmail_data`."
  type        = list(string)
  default     = ["/backup-sources/docker-volumes/protonmail-bridge_protonmail_data/_data"]
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
