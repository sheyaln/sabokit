# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Apps consume { scaleway, compute, domains } from this. authentik is not consumed by this bundle — the privacy policy page is intentionally public."
  type        = any
}

variable "hostname" {
  description = "Full hostname the privacy policy is served at (e.g. \"privacy.example.org\")."
  type        = string
  default     = ""
}

variable "dns_zone_override" {
  description = "Override the DNS zone the per-app A record lands in. Default empty derives the zone from var.hostname by longest-suffix match against var.base.domains.zones. Set explicitly only for edge cases where derivation produces the wrong zone."
  type        = string
  default     = ""
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, the privacy-policy access log paths wire in."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to."
  type        = string
  default     = "apps"
}

# ── Privacy-policy-specific inputs ──────────────────────────────────────────
#
# The HTML content + logo are NOT generated here — they're org-specific text
# (legal language, branding) that consumers author. Pass file paths or inline
# strings on the Ansible side (privacy_policy_html_path /
# privacy_policy_logo_path role variables). If left at defaults, the bundle
# ships a generic placeholder page so the deploy doesn't fail empty.

variable "page_title" {
  description = "<title> shown in the browser tab. Doesn't affect the body HTML."
  type        = string
  default     = "Privacy Policy"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts nginx when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default false."
  type        = bool
  default     = false
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/privacy-policy`. Use for named docker volumes, etc."
  type        = list(string)
  default     = []
}

variable "backup_schedule_cron" {
  description = "Backrest cron (6-field, seconds first). Default 02:00 UTC daily."
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

variable "extra_docker_networks" {
  description = "Extra docker networks to attach the bundle's main container to alongside its traefik network. Networks must already exist on the host. Use for cross-bundle integration with sidecars in other bootstrap-tier networks."
  type        = list(string)
  default     = []
}
