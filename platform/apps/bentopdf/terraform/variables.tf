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
  description = "Full hostname BentoPDF is served at (e.g. \"pdf.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Tools"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "PDF Tools (BentoPDF)"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`bentopdf`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
  type        = string
  default     = ""
}

variable "icon_url" {
  description = "Full icon URL override. When set, used verbatim and `icon_filename` is ignored. Empty string falls back to `$${base.authentik.icon_base_url}/$${icon_filename}` (or no icon when `icon_filename` is also empty)."
  type        = string
  default     = ""
}

variable "icon_filename" {
  description = "Icon filename fetched from `base.authentik.icon_base_url`. Empty disables the icon. Overridden by `icon_url`."
  type        = string
  default     = "bentopdf-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"member\"."
  type        = string
  default     = "member"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access BentoPDF beyond access_level. Map of role-name → group ID; keys MUST be static strings so for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "tier_cascade_enabled" {
  description = "Whether to derive authorized_groups from the platform tier cascade (member→delegate→treasurer→admin; each tier inherits all lower tiers). Default true. Set false to use the primitive access_level + extra_authorized_groups path instead."
  type        = bool
  default     = true
}

variable "tier_access_level" {
  description = "Cascade tier required for baseline access. Users in this tier and any higher tier are admitted. Only consulted when tier_cascade_enabled = true."
  type        = string
  default     = "member"
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, BentoPDF's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to. The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── BentoPDF-specific inputs ────────────────────────────────────────────────

variable "image" {
  description = "Full BentoPDF Docker image reference (repository + optional tag). Default is the official image published by the upstream project at github.com/alam00000/bentopdf. `ghcr.io/digital-blueprint/bento-pdf` is an unrelated project from a different org."
  type        = string
  default     = "ghcr.io/alam00000/bentopdf:latest"
}

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle (if deployed on this host) auto-pulls newer image versions for BentoPDF. Default true — BentoPDF is stateless, browser-only, and has no migration risk on image bumps."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed on this host) restarts BentoPDF when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default false."
  type        = bool
  default     = false
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/bentopdf`. Use for named docker volumes, etc."
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
