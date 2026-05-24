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

variable "storage_class" {
  description = "Scaleway storage class the attachments bucket transitions objects to. `STANDARD` (default) keeps everything Multi-AZ. `ONEZONE_IA` halves the storage cost at the price of single-AZ durability; sensible for outline attachments since the canonical doc body lives in postgres. `GLACIER` is wrong here — attachments load on every doc view, restore costs would dominate."
  type        = string
  default     = "STANDARD"
}

variable "storage_class_transition_days" {
  description = "Days after upload before objects move to `storage_class`. Only consulted when storage_class != STANDARD."
  type        = number
  default     = 1
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up Outline's host-side state. Default true. Plan id = bundle slug; paths = `/backup-sources/opt/outline` plus any `backup_extra_paths`."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/outline`. Use for named docker volumes, e.g. `[\"/backup-sources/docker-volumes/outline_storage-data/_data\"]`."
  type        = list(string)
  default     = []
}

variable "backup_schedule_cron" {
  description = "Backrest cron (6-field, seconds first) for Outline's plan. Default 02:00 UTC daily."
  type        = string
  default     = "0 0 2 * * *"
}

variable "backup_retention" {
  description = "Restic retention policy for Outline's backup plan."
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

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle (if deployed on this host) auto-pulls newer Outline image versions. Default true — Outline has stable migration story for minor versions; majors are rare and pin-tag-safe via image_tag."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Outline when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "oidc_username_claim" {
  description = "OIDC claim Outline reads as the username. Authentik exposes both `preferred_username` (usually the email-local part or AK username) and `sub` (the stable UUID). Default matches Outline's documented expectation; switch to `sub` for installs where usernames change."
  type        = string
  default     = "preferred_username"
}
