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
  description = "Full hostname Vikunja is served at (e.g. \"tasks.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Productivity"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"vikunja-icon.png\")."
  type        = string
  default     = null
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

variable "oidc_groups_scope_name" {
  description = "Custom OIDC scope name the Authentik provider attaches a `vikunja_groups` claim under. Vikunja uses this claim to auto-assign team memberships. Default matches the Authentik scope convention for this app."
  type        = string
  default     = "vikunja_scope"
}
