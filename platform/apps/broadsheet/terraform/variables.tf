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
  description = "Full hostname Broadsheet is served at (e.g. \"email.example.org\"). Never assembled from a subdomain prefix inside the module."
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
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries."
  type        = string
  default     = "Broadsheet"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`broadsheet`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "broadsheet-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Broadsheet beyond access_level. Map of role-name → group ID; keys MUST be static strings so for_each can plan even when group IDs are not yet known."
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
  description = "If true and a monitoring app is enabled, Broadsheet's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to. The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Broadsheet-specific inputs ──────────────────────────────────────────────

variable "image" {
  description = "Broadsheet Docker image repository (without tag). The default pulls the published sabokit-broadsheet image — flip `build_from_source = true` to build from a git checkout on the host instead."
  type        = string
  default     = "ghcr.io/sheyaln/broadsheet"
}

variable "image_tag" {
  description = "Broadsheet Docker image tag. Pin in production."
  type        = string
  default     = "latest"
}

variable "build_from_source" {
  description = "Opt-in: build the Broadsheet image on the deployment host from a cloned git repo instead of pulling. Default `false` — published images are the supported path. Set true only when you need an unreleased patch on the fork; when true, `image_source_repo` + `image_source_ref` define the checkout, the resulting image is tagged `broadsheet-local:latest` on the host, and `image`/`image_tag` are ignored."
  type        = bool
  default     = false
}

variable "image_source_repo" {
  description = "Git URL the host clones when `build_from_source = true`. Defaults to the sabokit-broadsheet fork."
  type        = string
  default     = "https://github.com/sheyaln/sabokit-broadsheet.git"
}

variable "image_source_ref" {
  description = "Git ref (branch, tag, or SHA) checked out when `build_from_source = true`. Defaults to `main`; pin to a tag or SHA for reproducibility."
  type        = string
  default     = "main"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Broadsheet when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "root_admin_email" {
  description = "Email address of the initial root administrator. Used both as the ROOT_EMAIL fallback identity and as ROOT_ADMIN_EMAIL for the bootstrap login. The matching password is auto-generated and stored in the app-secrets bag."
  type        = string
}

variable "smtp_from_email" {
  description = "From: address for Broadsheet-sent transactional email (e.g. \"notify@example.org\"). Required — Broadsheet uses SMTP heavily. SMTP host/port/username/password come from the platform-wide smtp-config secret looked up by the Ansible role."
  type        = string
  default     = ""
}

variable "oidc_auto_provision" {
  description = "Whether Broadsheet auto-provisions a user record on first OIDC login. Set false to require pre-created users."
  type        = bool
  default     = true
}

variable "oidc_allow_magic_code" {
  description = "Whether Broadsheet offers its magic-code (email link) fallback alongside OIDC. Recommended to leave on so admins can recover if OIDC is misconfigured."
  type        = bool
  default     = false
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/broadsheet`. Use for named docker volumes, etc."
  type        = list(string)
  default     = []
}

variable "storage_class" {
  description = "Scaleway storage class the files bucket transitions objects to. Default `STANDARD` (Multi-AZ). `ONEZONE_IA` halves the storage cost for template/asset buckets that don't see traffic spikes; reasonable for small deployments."
  type        = string
  default     = "STANDARD"
}

variable "storage_class_transition_days" {
  description = "Days after upload before objects move to `storage_class`. Only consulted when storage_class != STANDARD."
  type        = number
  default     = 1
}

variable "bucket_name_override" {
  description = "Override the Scaleway object bucket name. Defaults to '$${secrets_namespace}-broadsheet-files'. Set to match an existing legacy bucket to enable in-place import without force-replace + data loss. ONLY the bucket name flips — IAM apps, secret names, etc. keep using the canonical slug. SHORT-LIVED: rsync data into the canonical naming pattern within a release cycle and drop this override; the knob is marked for removal in v4.0."
  type        = string
  default     = ""
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

