# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, the bundle skips `random_password` generation (N8N_ENCRYPTION_KEY, N8N_RUNNERS_AUTH_TOKEN) and skips creating the Authentik service-account token (`authentik_token.service_n8n`), reading all these values from the live `n8n-app-secrets` bag via a data source. ENCRYPTION_KEY rotation is irrecoverable — it decrypts every stored workflow credential — so this flag is the gate for safe in-place v3 cutover. Also passed through to OIDC and database submodules. Drop after cutover; short-lived, removal slated for v4.x."
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

variable "dns_zone_override" {
  description = "Override the DNS zone the per-app A record lands in. Default empty derives the zone from var.hostname by longest-suffix match against var.base.domains.zones. Set explicitly only for edge cases where derivation produces the wrong zone."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Automation"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Workflows (n8n)"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`n8n`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "n8n-icon.png"
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
  description = "If true and a monitoring app is enabled, n8n's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "service_account_extra_groups" {
  description = "Authentik group names (must exist in var.base.authentik.groups — typically created via identity's var.extra_groups) that the n8n service account is added to alongside `authentik Admins`. Use for org-specific scopes (e.g. \"union-automation\", \"coop-ops\") consumed by workflow logic. Empty default; consumer-template surfaces via apps.n8n.service_account_extra_groups."
  type        = list(string)
  default     = []
}

variable "service_account_extra_group_ids" {
  description = "Direct Authentik group IDs (UUIDs) to add the n8n service account to, in addition to `service_account_extra_groups` (which takes group names from base.authentik.groups). Use this for cross-bundle wiring — e.g. consumer-template adds broadsheet's per-app group ID here when broadsheet is also enabled."
  type        = list(string)
  default     = []
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

variable "extra_env_vars" {
  description = "Extra environment variables rendered into the n8n container's .env. Map of KEY → value. The consumer-template aggregates contributions from other bundles (broadsheet, espocrm, identity Slack channels, etc.) so workflow JSONs in platform/identity/n8n-workflows/ stay org-agnostic and reference them via `$env.KEY`. Empty default; bundles never read each other directly."
  type        = map(string)
  default     = {}
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
