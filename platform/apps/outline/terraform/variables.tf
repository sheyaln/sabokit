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

variable "dns_zone_override" {
  description = "Override the DNS zone the per-app A record lands in. Default empty derives the zone from var.hostname by longest-suffix match against var.base.domains.zones. Set explicitly only for edge cases where derivation produces the wrong zone."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Knowledge"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Wiki (Outline)"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`outline`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "outline-icon.png"
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

variable "bucket_name_override" {
  description = "Override the Scaleway object bucket name. Defaults to '$${secrets_namespace}-outline-attachments'. Set to match an existing legacy bucket to enable in-place import without force-replace + data loss. ONLY the bucket name flips — IAM apps, secret names, etc. keep using the canonical slug. SHORT-LIVED: rsync data into the canonical naming pattern within a release cycle and drop this override; the knob is marked for removal in v4.0."
  type        = string
  default     = ""
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

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Outline when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, the bundle skips `random_*` generation for app-level secrets (SECRET_KEY, UTILS_SECRET) and reads them from the live `outline-app-secrets` bag via a data source; the flag is also passed through to the OIDC and database submodules so their credentials are preserved end-to-end. Drop on the next apply after cutover verification; short-lived, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "credentials_preserve_source" {
  description = "Greenfield-to-v3 cutover support. Sibling to `credentials_preserve` (gated separately, both null/false by default). When non-null AND `credentials_preserve = false`, this map supplies canonical keys directly into the bundle's `<slug>-app-secrets` Scaleway bag on the first apply instead of pulling them from a pre-populated one. Schema (canonical keys this bundle reads): `SECRET_KEY`, `UTILS_SECRET`. Supply only the keys you want to seed; any not supplied fall back to the bundle's generated `random_password` values. Only covers the bundle's own app-secrets bag — OIDC and database credentials are handled by their own preserve paths on the inner submodules. After the first apply, `ignore_changes = [data]` on the bag version keeps the values pinned and the variable can be dropped (or flipped to `credentials_preserve = true`). The map is plaintext in consumer TF — put it behind a Scaleway data source or a gitignored file."
  type        = map(string)
  default     = null
  sensitive   = true
}

variable "oidc_username_claim" {
  description = "OIDC claim Outline reads as the username. Authentik exposes both `preferred_username` (usually the email-local part or AK username) and `sub` (the stable UUID). Default matches Outline's documented expectation; switch to `sub` for installs where usernames change."
  type        = string
  default     = "preferred_username"
}

variable "extra_docker_networks" {
  description = "Extra docker networks to attach the bundle's main container to alongside its traefik network. Networks must already exist on the host. Use for cross-bundle integration with sidecars in other bootstrap-tier networks."
  type        = list(string)
  default     = []
}
