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
  description = "Full hostname Nextcloud is served at (e.g. \"cloud.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Files"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"nextcloud-icon.png\")."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"member\"."
  type        = string
  default     = "member"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Nextcloud beyond access_level. Map of role-name → group ID; keys MUST be static strings (e.g. \"delegate\", \"manager\") so the underlying for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Nextcloud's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to (e.g. \"apps\", \"tools\"). The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Nextcloud-specific inputs ───────────────────────────────────────────────

variable "image_tag" {
  description = "Nextcloud Docker image tag. Pin to a major version (e.g. \"32-apache\") rather than \"latest\" — Nextcloud only supports one-major-at-a-time upgrades."
  type        = string
  default     = "32-apache"
}

variable "admin_username" {
  description = "Bootstrap admin username created on first install. OIDC users sign in separately; this account is the fallback if OIDC is misconfigured."
  type        = string
  default     = "ncadmin"
}

variable "default_phone_region" {
  description = "ISO 3166-1 alpha-2 country code used by Nextcloud to format phone numbers when no region is supplied (e.g. \"US\", \"DE\", \"FR\")."
  type        = string
  default     = "US"
}

variable "max_upload_size_bytes" {
  description = "Largest file Nextcloud accepts via upload. Default 2147483648 = 2 GiB. The Apache body limit is set to match."
  type        = number
  default     = 2147483648
}

variable "trusted_proxies" {
  description = "CIDR block trusted as a reverse proxy. Defaults to the Docker bridge range so Traefik's X-Forwarded-* headers are honoured. Override to a tighter CIDR if traffic enters Nextcloud through a non-Docker proxy."
  type        = string
  default     = "172.16.0.0/12"
}

variable "smtp_from_email" {
  description = "From: address used by Nextcloud for transactional email (e.g. \"cloud@example.org\"). Empty disables SMTP. SMTP host/port/username/password come from the platform-wide smtp-config secret looked up by the Ansible role."
  type        = string
  default     = ""
}
