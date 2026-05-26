# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, the bundle skips `random_password.jwt_secret` and reads `VIKUNJA_SERVICE_JWTSECRET` from the live `vikunja-app-secrets` bag via a data source. Rotating the JWT secret invalidates every issued API token. Also passed through to OIDC and database submodules. Drop after cutover; short-lived, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Apps consume { scaleway, authentik, compute, domains } from this. Shape documented in /ARCHITECTURE.md (\"What base/ outputs\")."
  type        = any
}

variable "hostname" {
  description = "Full hostname Vikunja is served at (e.g. \"tasks.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "dns_zone_override" {
  description = "Override the DNS zone the per-app A record lands in. Default empty derives the zone from var.hostname by longest-suffix match against var.base.domains.zones. Set explicitly only for edge cases where derivation produces the wrong zone."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Productivity"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Tasks (Vikunja)"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`vikunja`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "vikunja-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"member\"."
  type        = string
  default     = "member"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Vikunja beyond access_level. Map of role-name → group ID; keys MUST be static strings (e.g. \"delegate\", \"manager\") so the underlying for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "tier_cascade_enabled" {
  description = "Whether to derive authorized_groups from the platform tier_slots cascade. When true, the app binds every group in base.authentik.tier_cascade[var.tier_access_level] (the peer's own group + all groups in strictly-higher slots). Default true. Set false to use the primitive access_level + extra_authorized_groups path instead."
  type        = bool
  default     = true
}

variable "tier_access_level" {
  description = "peer_name from your tier_slots schema that grants baseline access. The app binds every group in base.authentik.tier_cascade[<this>], which is the peer's own group plus every group in every strictly-higher slot. Only consulted when tier_cascade_enabled = true. Default \"admin\" — the safest fallback (admin must exist as a peer in tier_slots); override per-app to the peer_name your org uses for the intended baseline (e.g. \"member\", \"delegate\")."
  type        = string
  default     = "admin"
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Vikunja's log paths + Traefik dashboard wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to (e.g. \"apps\", \"tools\"). The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Vikunja-specific inputs ─────────────────────────────────────────────────

variable "image_tag" {
  description = "Vikunja Docker image tag."
  type        = string
  default     = "latest"
}

variable "timezone" {
  description = "IANA timezone for the server. Affects reminder times and recurring-task next-run calculations."
  type        = string
  default     = "UTC"
}

variable "enable_registration" {
  description = "Whether Vikunja's built-in local-account registration is enabled. Independent of OIDC; with `enable_local_auth = false` (the default) leaving this on still has no practical effect because local password login is blocked. Kept as an explicit knob so operators who flip local auth back on know how to gate signups."
  type        = bool
  default     = false
}

variable "enable_local_auth" {
  description = "Whether Vikunja accepts username+password logins in addition to OIDC. Default false — federated SSO via Authentik is the only sign-in path."
  type        = bool
  default     = false
}

variable "smtp_from_email" {
  description = "From: address for Vikunja transactional email. Empty disables SMTP entirely. Set explicitly (e.g. \"tasks@example.org\") when an SMTP secret exists in base."
  type        = string
  default     = ""
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up Vikunja's host-side state. Default true — Vikunja keeps attachments in `/opt/vikunja/files` which is not in S3 and would be lost on host loss without backrest."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/vikunja`. Use for named docker volumes."
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

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Vikunja when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "default_week_start" {
  description = "Day the week starts on in Vikunja's calendar views. `0` = Sunday, `1` = Monday. Leave null to let Vikunja use its built-in default (per-user, no global override)."
  type        = number
  default     = null
  validation {
    condition     = var.default_week_start == null || (var.default_week_start >= 0 && var.default_week_start <= 6)
    error_message = "default_week_start must be null or an integer in [0, 6]."
  }
}

variable "oidc_groups_scope_name" {
  description = "OIDC scope the Authentik provider attaches the groups claim under. Default `groups` is Authentik's stock scope and works without extra provider setup. Override only if you've defined a custom scope mapping (e.g. `vikunja_scope`) in Authentik and want the provider bound to it — that requires the scope to exist in Authentik first, or the provider apply errors out."
  type        = string
  default     = "groups"
}
