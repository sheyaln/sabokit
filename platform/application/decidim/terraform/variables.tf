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

variable "dns_zone_override" {
  description = "Override the DNS zone the per-app A record lands in. Default empty derives the zone from var.hostname by longest-suffix match against var.base.domains.zones. Set explicitly only for edge cases where derivation produces the wrong zone."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Participation"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Decidim"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`decidim`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "decidim-icon.png"
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
  description = "Decidim Docker image (without tag) used as the BASE for the locally-built image. The Ansible role extends this image with `extra_gems` and re-runs `bundle install` + `assets:precompile`. Decidim publishes via Docker Hub at decidim/decidim."
  type        = string
  default     = "decidim/decidim"
}

variable "image_tag" {
  description = "Decidim Docker image tag. Pin to a release tag (e.g. \"0.31.5\") for production; \"latest\" follows the project's published latest. Same tag is used as the version for every gem in `extra_gems` (Decidim modules version-lock to the core). Bump per Decidim's release cadence."
  type        = string
  default     = "0.31.5"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
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

variable "organization_admin_name" {
  description = "Display name for the bootstrap organization admin. Empty falls back to \"<organization_name> Admin\" inside the seed runner (pre-knob behaviour). Only consumed on first deploy when the admin user is created."
  type        = string
  default     = ""
}

variable "organization_admin_nickname" {
  description = "Nickname (URL-safe handle) for the bootstrap organization admin. Empty falls back to `admin`. Only consumed on first deploy."
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

variable "storage_public" {
  description = "Whether uploaded attachments should be served as public objects (inline) versus through signed URLs. Decidim's storage layer expects a boolean via the AWS_PUBLIC env var. Default `true` matches the public-attachment posture; flip to `false` to gate every download behind a signed URL."
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Scaleway storage class the uploads bucket transitions objects to. Default `STANDARD` (Multi-AZ). `ONEZONE_IA` halves the storage cost for proposals/comments with attachments that aren't accessed frequently; weigh against the single-AZ durability tradeoff."
  type        = string
  default     = "STANDARD"
}

variable "storage_class_transition_days" {
  description = "Days after upload before objects move to `storage_class`. Only consulted when storage_class != STANDARD."
  type        = number
  default     = 1
}

variable "bucket_name_override" {
  description = "Override the Scaleway object bucket name. Defaults to '$${secrets_namespace}-decidim-uploads'. Set to match an existing legacy bucket to enable in-place import without force-replace + data loss. ONLY the bucket name flips — IAM apps, secret names, etc. keep using the canonical slug. SHORT-LIVED: rsync data into the canonical naming pattern within a release cycle and drop this override; the knob is marked for removal in v4.0."
  type        = string
  default     = ""
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

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/decidim`. Use for named docker volumes, etc."
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

variable "extra_env_vars" {
  description = "Map of KEY → value rendered into the container .env after first-class vars. Use for env-driven feature flags / third-party integrations / debug toggles not exposed first-class on the bundle."
  type        = map(string)
  default     = {}
}

variable "extra_docker_networks" {
  description = "Extra docker networks to attach the bundle's main container to alongside its traefik network. Networks must already exist on the host. Use for cross-bundle integration with sidecars in other bootstrap-tier networks."
  type        = list(string)
  default     = []
}


variable "authorized_groups" {
  description = "Authentik group NAMES allowed to access this app; each must exist in base.authentik.groups (declared in your tier_slots/extra_groups). The bundle binds one access policy per group. Tiering/cascade is a consumer decision — list every group that should have access. Default [\"admin\"] = admin-only."
  type        = list(string)
  default     = ["admin"]
}
