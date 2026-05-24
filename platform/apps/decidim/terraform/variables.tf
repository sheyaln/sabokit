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
  description = "Full hostname Decidim is served at (e.g. \"participate.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Participation"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"decidim-icon.png\")."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"member\"."
  type        = string
  default     = "member"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Decidim beyond access_level. Map of role-name → group ID; keys MUST be static strings so for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Decidim's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to (e.g. \"apps\", \"tools\"). The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Decidim-specific inputs ─────────────────────────────────────────────────

variable "image" {
  description = "Decidim Docker image (without tag) used as the BASE for the locally-built image. The Ansible role extends this image with `extra_gems` and re-runs `bundle install` + `assets:precompile`. Decidim publishes via ghcr.io/decidim/decidim."
  type        = string
  default     = "ghcr.io/decidim/decidim"
}

variable "image_tag" {
  description = "Decidim Docker image tag. Pin to a release tag (e.g. \"0.30.0\") for production; \"latest\" follows the project's published latest. Same tag is used as the version for every gem in `extra_gems` (Decidim modules version-lock to the core)."
  type        = string
  default     = "latest"
}

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle (if deployed) auto-pulls newer Decidim image versions. Default FALSE — Decidim is a Rails app with non-trivial schema migrations and the locally-built image (when extra_gems is non-empty) wouldn't be touched by Watchtower anyway. Consumers bump image_tag explicitly."
  type        = bool
  default     = false
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts the Decidim app container when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "extra_gems" {
  description = "Decidim modular gems to add on top of the base image, each pinned to `image_tag`. The base `decidim` meta-gem ships proposals, meetings, debates, assemblies, etc. — but optional modules like `decidim-elections` are NOT included and must be added explicitly. Default ships elections because every participatory-democracy deployment eventually wants it. Set to `[]` for a lean install."
  type        = list(string)
  default     = ["decidim-elections"]
}

variable "organization_name" {
  description = "Display name of the participatory democracy organization. Used to bootstrap the first Decidim organization on initial boot. Free text (\"Example Assembly\")."
  type        = string
}

variable "organization_reference_prefix" {
  description = "Short uppercase prefix Decidim uses on internal reference numbers (e.g. \"EXA\"). Two to six uppercase letters; falls back to the first three letters of organization_name if unset."
  type        = string
  default     = ""
}

variable "default_locale" {
  description = "Two-letter ISO 639-1 locale Decidim defaults to (e.g. \"en\", \"es\", \"ca\")."
  type        = string
  default     = "en"

  validation {
    condition     = can(regex("^[a-z]{2}$", var.default_locale))
    error_message = "default_locale must be a two-letter lowercase ISO 639-1 code (e.g. \"en\")."
  }
}

variable "available_locales" {
  description = "Locales Decidim makes available in the UI. Must include default_locale."
  type        = list(string)
  default     = ["en"]

  validation {
    condition     = length(var.available_locales) > 0
    error_message = "available_locales must contain at least one locale."
  }
}

variable "system_admin_email" {
  description = "Email of the initial /system superuser. Used to bootstrap Decidim on first boot; the matching password is auto-generated and stored in the app-secrets bag."
  type        = string
}

variable "organization_admin_email" {
  description = "Email of the first organization admin (separate from the /system superuser). Defaults to system_admin_email when empty."
  type        = string
  default     = ""
}

variable "smtp_from_email" {
  description = "From: address for Decidim-sent transactional email. Empty disables SMTP wiring on the host. SMTP host/port/username/password come from the platform-wide smtp-config secret looked up by the Ansible role."
  type        = string
  default     = ""
}

variable "max_upload_size_bytes" {
  description = "Largest file Decidim accepts via upload. Default 26214400 = 25 MiB."
  type        = number
  default     = 26214400
}

variable "storage_bucket_acl" {
  description = "ACL for the uploads S3 bucket. Decidim serves public-facing attachments inline; \"public-read\" matches that without forcing signed URLs."
  type        = string
  default     = "public-read"
}

variable "sidekiq_concurrency" {
  description = "Sidekiq worker thread count. Decidim's background queues (emails, search indexing, notifications) drain through this single sidekiq container."
  type        = number
  default     = 5

  validation {
    condition     = var.sidekiq_concurrency >= 1
    error_message = "sidekiq_concurrency must be at least 1."
  }
}
