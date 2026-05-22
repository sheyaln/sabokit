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
  description = "Full hostname Outline is served at (e.g. \"wiki.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Knowledge"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"outline-icon.png\")."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"member\"."
  type        = string
  default     = "member"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Outline beyond access_level. Map of role-name → group ID; keys MUST be static strings (e.g. \"delegate\", \"manager\") so the underlying for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Outline's metrics/dashboards are wired in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to (e.g. \"apps\", \"tools\"). The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Outline-specific inputs ─────────────────────────────────────────────────

variable "image_tag" {
  description = "Outline Docker image tag."
  type        = string
  default     = "latest"
}

variable "smtp_from_email" {
  description = "From: address used by Outline for transactional email. Empty disables SMTP. Set explicitly (e.g. \"wiki@example.org\") when an SMTP secret exists in base."
  type        = string
  default     = ""
}

variable "max_upload_size_bytes" {
  description = "Largest file Outline accepts via upload. Default 26214400 = 25 MiB."
  type        = number
  default     = 26214400
}

variable "storage_bucket_acl" {
  description = "ACL for the attachments S3 bucket. Outline needs at least \"public-read\" for shared documents to load attachments without signed URLs."
  type        = string
  default     = "public-read"
}
