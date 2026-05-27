# ── Contract inputs ─────────────────────────────────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, the bundle skips `random_password` generation for the three Wazuh internal-user passwords (indexer admin, manager API, dashboard) and reads them from the live `wazuh-app-secrets` bag via a data source. The opensearch-security bootstrap bakes these into the security index on first start — rotating requires `wazuh-passwords-tool` inside the manager container. Also passed through to the OIDC submodule. Drop after cutover; short-lived, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "credentials_preserve_source" {
  description = "Greenfield-to-v3 cutover support. Sibling to `credentials_preserve` (gated separately, both null/false by default). When non-null AND `credentials_preserve = false`, this map supplies canonical keys directly into the bundle's `<slug>-app-secrets` Scaleway bag on the first apply instead of pulling them from a pre-populated one. Schema (canonical keys this bundle reads): `WAZUH_INDEXER_PASSWORD`, `WAZUH_API_PASSWORD`, `WAZUH_DASHBOARD_PASSWORD`. Supply only the keys you want to seed; any not supplied fall back to the bundle's generated `random_password` values. Only covers the bundle's own app-secrets bag — OIDC and database credentials are handled by their own preserve paths on the inner submodules. After the first apply, `ignore_changes = [data]` on the bag version keeps the values pinned and the variable can be dropped (or flipped to `credentials_preserve = true`). The map is plaintext in consumer TF — put it behind a Scaleway data source or a gitignored file."
  type        = map(string)
  default     = null
  sensitive   = true
}

variable "base" {
  description = "Outputs from module \"base\"."
  type        = any
}

variable "hostname" {
  description = "Full hostname the Wazuh dashboard is served at (e.g. \"wazuh.example.org\")."
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
  default     = "Security"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Wazuh"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`wazuh`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "wazuh-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"admin\" — Wazuh exposes SIEM data + active response controls, ops-only by default."
  type        = string
  default     = "admin"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed beyond access_level."
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
  description = "If true and a monitoring app is enabled, Wazuh's log paths wire in."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this Wazuh manager runs on. Typically your monitoring/security host."
  type        = string
  default     = "management"
}

# ── Wazuh-specific inputs ───────────────────────────────────────────────────

variable "release_version" {
  description = "Wazuh release version (used for ALL three images: manager, indexer, dashboard, and the cert generator). The three images MUST run lockstep."
  type        = string
  default     = "4.9.0"
}

variable "oidc_admin_group" {
  description = "Authentik group whose members are mapped to opensearch's `all_access` role inside Wazuh. Matches against the OIDC `groups` claim."
  type        = string
  default     = "admin"
}

variable "oidc_readonly_group" {
  description = "Optional Authentik group mapped to opensearch's `kibana_user` + `readall` roles — dashboard access without write/active-response privileges. Empty string disables (admin-only access)."
  type        = string
  default     = ""
}

variable "indexer_heap_size" {
  description = "JVM heap size for the indexer (OpenSearch). Rule of thumb: 50%% of host RAM, max 31g. Bump for larger event volumes."
  type        = string
  default     = "1g"
}

variable "manager_agent_port" {
  description = "TCP port the Wazuh manager listens on for agent connections."
  type        = number
  default     = 1514
}

variable "manager_enrollment_port" {
  description = "TCP port the Wazuh manager listens on for agent enrollment."
  type        = number
  default     = 1515
}

variable "manager_syslog_port" {
  description = "UDP port the Wazuh manager listens on for syslog ingestion."
  type        = number
  default     = 514
}

variable "memory_limit" {
  description = "Container memory ceiling — applies to the manager (the indexer's heap is set separately via indexer_heap_size)."
  type        = string
  default     = "2G"
}

variable "memory_reservation" {
  description = "Container memory reservation for the manager."
  type        = string
  default     = "512M"
}

variable "cpu_limit" {
  description = "Container CPU ceiling for the manager."
  type        = string
  default     = "2.0"
}

variable "cpu_reservation" {
  description = "Container CPU reservation for the manager."
  type        = string
  default     = "0.5"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle restarts Wazuh containers on healthcheck failure. Default true."
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle backs up Wazuh's indexer data + manager state. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths. The indexer + manager state lives in named volumes; defaults below cover them."
  type        = list(string)
  default = [
    "/backup-sources/docker-volumes/wazuh_wazuh-indexer-data/_data",
    "/backup-sources/docker-volumes/wazuh_wazuh_etc/_data",
    "/backup-sources/docker-volumes/wazuh_wazuh_api_configuration/_data",
  ]
}

variable "backup_schedule_cron" {
  description = "Backrest cron (6-field). Default 02:00 UTC daily."
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

