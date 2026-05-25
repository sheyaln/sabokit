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
  description = "Full hostname Steward is served at (e.g. \"members.example.org\")."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Administration"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Steward"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`steward`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "steward-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"admin\" because Steward is itself an admin surface."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Steward beyond access_level. Map of role-name → group ID; keys MUST be static strings (e.g. \"delegate\", \"manager\") so the underlying for_each can plan even when group IDs are not yet known."
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
  default     = "admin"
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Steward's metrics/dashboards are wired in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "service_account_extra_groups" {
  description = "Authentik group names (must exist in var.base.authentik.groups — typically created via identity's var.extra_groups) that the Steward service account is added to alongside `authentik Admins`. Empty default — Steward's bearer-token API access through the admins group is usually sufficient; expose for parity with n8n in case a consumer's authorization model needs the SA scoped into custom groups."
  type        = list(string)
  default     = []
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to (e.g. \"apps\", \"tools\"). The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Steward-specific inputs ─────────────────────────────────────────────────

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle (if deployed) auto-pulls newer Steward image versions. Default true — Steward is the maintainer's own app with a stable migration contract; the qcluster sidecar pulls in lockstep."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Steward when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "image_repository" {
  description = "OCI repository of the Steward image (without tag). Defaults to the canonical pre-beta location; consumers can repoint to their own mirror."
  type        = string
  default     = "ghcr.io/sheyaln/sabokit-steward"
}

variable "image_tag" {
  description = "Steward Docker image tag."
  type        = string
  default     = "latest"
}

variable "admin_group_name" {
  description = "Name of the Authentik group whose members are granted Steward admin access. Must match the access_level group name in Authentik so the OIDC `groups` claim contains it for authorized users."
  type        = string
  default     = "steward-admins"
}

variable "invite_flow_slug" {
  description = "Slug of an Authentik enrollment flow Steward attaches to invitations when adding members. Empty disables invitation creation (members get no invite link / email)."
  type        = string
  default     = ""
}

variable "memory_limit" {
  description = "Memory cap for the Steward web container."
  type        = string
  default     = "512M"
}

variable "memory_reservation" {
  description = "Memory reservation for the Steward web container."
  type        = string
  default     = "128M"
}

variable "cpu_limit" {
  description = "CPU cap for the Steward web container."
  type        = string
  default     = "0.5"
}

variable "cpu_reservation" {
  description = "CPU reservation for the Steward web container."
  type        = string
  default     = "0.1"
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/steward`. Use for named docker volumes, etc."
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
