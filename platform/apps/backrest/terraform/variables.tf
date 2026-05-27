# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, the bundle skips `random_password.restic` and reads RESTIC_PASSWORD from the live `backrest-<instance_name>-app-secrets` bag via a data source. Restic encrypts the entire repo with this password — losing it makes every snapshot unrecoverable. Also passed through to the OIDC submodule. Drop after cutover; short-lived, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "credentials_preserve_source" {
  description = "Greenfield-to-v3 cutover support. Sibling to `credentials_preserve` (gated separately, both null/false by default). When non-null AND `credentials_preserve = false`, this map supplies canonical keys directly into the bundle's `<slug>-app-secrets` Scaleway bag on the first apply instead of pulling them from a pre-populated one. Schema (canonical keys this bundle reads): `RESTIC_PASSWORD`. Supply only the keys you want to seed; any not supplied fall back to the bundle's generated `random_password` values. Only covers the bundle's own app-secrets bag — OIDC and database credentials are handled by their own preserve paths on the inner submodules. After the first apply, `ignore_changes = [data]` on the bag version keeps the values pinned and the variable can be dropped (or flipped to `credentials_preserve = true`). The map is plaintext in consumer TF — put it behind a Scaleway data source or a gitignored file."
  type        = map(string)
  default     = null
  sensitive   = true
}

variable "base" {
  description = "Outputs from module \"base\". Apps consume { scaleway, authentik, compute, domains } from this. Shape documented in /ARCHITECTURE.md (\"What base/ outputs\")."
  type        = any
}

variable "hostname" {
  description = "Full hostname this Backrest instance is served at (e.g. \"backup.tools.example.org\"). Never assembled from a subdomain prefix inside the module."
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
  default     = "Operations"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Empty default keeps the stock per-instance shape `Backrest (<instance_name>)`; override per-consumer for branded portal entries."
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
  default     = "backrest-icon.png"
}

variable "storage_class" {
  description = "Scaleway storage class the restic-repository bucket transitions snapshots to. Default `GLACIER` — restic data is cold by definition, read only during restore drills. `STANDARD` (Multi-AZ) is ~6x more expensive for no operational benefit since restic verifies its own integrity. Override to STANDARD only if you actively run frequent restores and want lower latency on snapshot list/check operations."
  type        = string
  default     = "GLACIER"
}

variable "storage_class_transition_days" {
  description = "Days after upload before snapshots move to `storage_class`. Default 90 to match Scaleway's GLACIER-tier 90-day-minimum transition requirement (S3 rejects shorter transitions for GLACIER with InvalidArgument). Restic is configured to upload directly into `storage_class` via `--option s3.storage-class=...`, so this lifecycle rule only catches pre-flag-wiring STANDARD objects — new snapshots skip the warm window entirely. Rule stays in place to migrate orphan STANDARD objects from before the cutover."
  type        = number
  default     = 90
}

variable "bucket_name_override" {
  description = "Override the Scaleway object bucket name. Defaults to '$${secrets_namespace}-$${qualified_slug}'. Set to match an existing legacy bucket to enable in-place import without force-replace + data loss. ONLY the bucket name flips — IAM apps, secret names, etc. keep using the canonical slug. SHORT-LIVED: rsync data into the canonical naming pattern within a release cycle and drop this override; the knob is marked for removal in v4.0."
  type        = string
  default     = ""
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"admin\" — Backrest exposes raw filesystem paths and restore controls, treat it as ops-only."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access this Backrest instance beyond access_level. Map of role-name → group ID; keys MUST be static strings so for_each can plan even when group IDs are not yet known."
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
  description = "If true and a monitoring app is enabled, Backrest's /metrics endpoint and log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Backrest instance deploys to. Each host being backed up should run its own instance pinned to that host's key."
  type        = string
}

# ── Backrest-specific inputs ────────────────────────────────────────────────

variable "instance_name" {
  description = "Per-instance name suffix. Backrest is typically deployed once per host being backed up; this string namespaces every cloud resource (S3 bucket, IAM principal, secret, Authentik app/group) so multiple instances under the same base do not collide. Lowercase letters, digits and hyphens only — used directly in resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.instance_name))
    error_message = "instance_name must be 3-32 chars, lowercase letters/digits/hyphens, not start or end with a hyphen."
  }
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates (POSTs to the n8n webhook on new tag-digest). Default true — opt out only if this app's image registry has a non-functional tag scheme or you don't want notification noise."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Backrest when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "image_tag" {
  description = "Backrest Docker image tag. Pin in production; the upstream `latest` tag moves frequently."
  type        = string
  default     = "latest"
}

variable "backup_plans" {
  description = <<-EOT
    Backup plans this instance will run. Each entry becomes an entry in
    Backrest's config.json `plans[]` array. `id` must be unique within the
    instance.

    Two shapes are accepted (the role merges both, so bundles can migrate
    incrementally):

    Legacy: `paths` listed verbatim — paths INSIDE the container; the default
    `backup_sources` mount `/opt` and `/var/lib/docker/volumes` from the host
    read-only, so a typical path is `/backup-sources/opt/<app>` or
    `/backup-sources/docker-volumes/<volume>/_data`.

    Content-aware (v2.14.0+):
      - `opt_dir = true` → adds `/backup-sources/opt/<id>` for free
      - `volumes = ["foo"]` → adds `/backup-sources/docker-volumes/foo/_data`
      - `excluded_volumes` → documentation only today, not rendered (a future
        per-volume retention story will read it)
      - `extra_paths` → one-off restic paths the bundle doesn't fit either bucket
      - `pre_hooks` / `post_hooks` → host shell commands wrapped as Backrest
        CONDITION_SNAPSHOT_START / CONDITION_SNAPSHOT_END action_command hooks.
        For quiescence (sqlite `.backup`, app-side flush) etc.

    A plan must end up with at least one of paths / opt_dir=true / volumes /
    extra_paths populated; the validation below enforces that.
  EOT
  type = list(object({
    id    = string
    paths = optional(list(string), [])
    # Content-aware additions (v2.14.0). All optional; legacy plans omit them.
    opt_dir          = optional(bool, false)
    volumes          = optional(list(string), [])
    excluded_volumes = optional(list(string), [])
    extra_paths      = optional(list(string), [])
    pre_hooks        = optional(list(string), [])
    post_hooks       = optional(list(string), [])
    excludes         = optional(list(string), [])
    schedule = object({
      cron = string
    })
    retention = object({
      hourly  = optional(number)
      daily   = optional(number)
      weekly  = optional(number)
      monthly = optional(number)
      yearly  = optional(number)
    })
  }))
  default = []

  validation {
    condition     = length(var.backup_plans) == length(distinct([for p in var.backup_plans : p.id]))
    error_message = "backup_plans entries must have unique `id` values within the instance."
  }

  validation {
    condition = alltrue([
      for p in var.backup_plans :
      length(p.paths) > 0 || p.opt_dir || length(p.volumes) > 0 || length(p.extra_paths) > 0
    ])
    error_message = "Each backup_plan must populate at least one of `paths`, `opt_dir = true`, `volumes`, or `extra_paths` — otherwise there is nothing to back up."
  }
}

variable "backup_sources" {
  description = "Host paths bind-mounted read-only into the container under /backup-sources/<key>. The default mounts /opt (apps' bind-mount data) and /var/lib/docker/volumes (named-volume data) which together cover everything sabokit apps persist. Extend (don't replace) when an app stores state outside these trees."
  type        = map(string)
  default = {
    "opt"            = "/opt"
    "docker-volumes" = "/var/lib/docker/volumes"
  }
}

variable "restic_prune_max_frequency_days" {
  description = "Minimum days between restic prune runs. Lower = more aggressive cleanup, higher I/O cost; higher = cheaper, more cold storage."
  type        = number
  default     = 7
}

variable "restic_check_max_frequency_days" {
  description = "Minimum days between restic repository integrity checks."
  type        = number
  default     = 30
}

variable "restic_check_read_data_subset_percent" {
  description = "Percentage of pack files restic reads back when running a scheduled check. 0 = metadata only (fast); higher catches bitrot but is bandwidth-heavy."
  type        = number
  default     = 5
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

