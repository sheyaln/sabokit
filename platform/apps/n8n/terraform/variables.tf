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
  description = "Full hostname n8n is served at (e.g. \"flows.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Automation"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"n8n-icon.png\")."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"admin\" — n8n is an ops tool with full credential access to every connected system."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access n8n beyond access_level. Map of role-name → group ID; keys MUST be static strings (e.g. \"delegate\", \"automator\") so the underlying for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, n8n's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to (e.g. \"apps\", \"tools\"). The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── n8n-specific inputs ─────────────────────────────────────────────────────

variable "image_tag" {
  description = "n8n image tag. Used for BOTH the n8n image and the matching n8nio/runners sidecar — upstream requires the runner version to match n8n exactly. Bump in lockstep."
  type        = string
  default     = "latest"
}

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle (if deployed) auto-pulls newer n8n image versions. Default FALSE — n8n schema migrations and the lock-step runner version requirement (n8nio/runners must match n8n exactly) make blind updates risky. Consumers bump image_tag explicitly and Ansible restarts both n8n + n8n-runners together."
  type        = bool
  default     = false
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts n8n when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "n8n_admin_group_name" {
  description = "Name of the Authentik group whose members the n8n hook promotes to n8n's `global:owner` role on first OIDC login. Members of other groups land as `global:member`. The first ever sign-in always becomes owner regardless of group (bootstrap). Must match a group claim emitted by the OIDC provider (Authentik's `groups` claim carries group names)."
  type        = string
  default     = "admin"
}

variable "timezone" {
  description = "IANA timezone for the n8n container. Affects cron schedules, recurring workflow next-run calculations, and timestamps in the editor UI."
  type        = string
  default     = "UTC"
}

variable "public_api_disabled" {
  description = "Whether n8n's public REST API is disabled. Defaults to true — n8n's API key auth is a high-value target since workflows hold credentials for every connected service. Flip to false only if a workflow actually needs API access."
  type        = bool
  default     = true
}

variable "python_stdlib_allow" {
  description = "Comma-separated list of Python stdlib modules workflows can `import` from the Code node. Upstream defaults to an empty allowlist that blocks even `json`; this default opens the common-safe set. Pass \"*\" to allow everything (less safe)."
  type        = string
  default     = "json,re,math,datetime,time,base64,hashlib,collections,itertools,functools,urllib,urllib.parse,uuid,string,decimal"
}

variable "python_external_allow" {
  description = "Comma-separated list of third-party Python packages the Code node may import. Default empty — only the stdlib allowlist applies. Add packages here once they're installed in the runners image."
  type        = string
  default     = ""
}

variable "webhook_rate_limit_average" {
  description = "Traefik rate-limit average requests/period for the webhook router. Webhooks bypass auth; this is the only thing standing between a public endpoint and a flood."
  type        = number
  default     = 100
}

variable "webhook_rate_limit_burst" {
  description = "Traefik rate-limit burst for the webhook router."
  type        = number
  default     = 50
}

variable "webhook_rate_limit_period" {
  description = "Traefik rate-limit period for the webhook router (Go duration syntax, e.g. \"1m\", \"30s\")."
  type        = string
  default     = "1m"
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/n8n`. Use for named docker volumes, etc."
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
