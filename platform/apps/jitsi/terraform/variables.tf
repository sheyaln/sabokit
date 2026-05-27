# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, the bundle skips `random_password` generation for all five Jitsi component credentials (JWT app secret, Jicofo + JVB + Jibri-XMPP + Jibri-recorder XMPP passwords) and reads them from the live `jitsi-app-secrets` bag via a single data source. Rotating any of these forces a stack restart and drops every active meeting. Also passed through to the OIDC submodule. Drop after cutover; short-lived, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Apps consume { scaleway, authentik, compute, domains } from this. Shape documented in /ARCHITECTURE.md (\"What base/ outputs\")."
  type        = any
}

variable "hostname" {
  description = "Full hostname Jitsi is served at (e.g. \"meet.example.org\"). Never assembled from a subdomain prefix inside the module."
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
  default     = "Communication"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Video Meetings (Jitsi)"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`jitsi`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "jitsi-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"member\". Only relevant when the OIDC adapter gates room creation — open-meeting deployments make this moot."
  type        = string
  default     = "member"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Jitsi beyond access_level. Map of role-name → group ID; keys MUST be static strings so the underlying for_each can plan even when group IDs are not yet known."
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
  description = "If true and a monitoring app is enabled, Jitsi's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to. The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Jitsi-specific inputs ───────────────────────────────────────────────────

variable "image_tag" {
  description = "Docker tag used for every jitsi/* image (web, prosody, jicofo, jvb). Pin to a stable-* tag in production; \"unstable\" tracks main."
  type        = string
  default     = "stable-9823"
}

variable "timezone" {
  description = "IANA timezone passed to every Jitsi container. Affects log timestamps and scheduled-meeting display in some clients."
  type        = string
  default     = "UTC"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Jitsi containers when their healthchecks fail. Default true."
  type        = bool
  default     = true
}

variable "jvb_udp_port" {
  description = "UDP port the Jitsi Videobridge listens on for WebRTC media. MUST be reachable from clients globally — open it on the deployment host's security group (typically via base.default_security_group_extra_inbound_rules) AND on the host firewall (the Ansible role opens UFW for you). 10000 is the Jitsi convention; change only if you're co-locating another JVB on the same host."
  type        = number
  default     = 10000

  validation {
    condition     = var.jvb_udp_port > 1024 && var.jvb_udp_port < 65536
    error_message = "jvb_udp_port must be an unprivileged port between 1025 and 65535."
  }
}

variable "jvb_stun_servers" {
  description = "Comma-separated list of host:port STUN servers JVB advertises to clients. Defaults to the public Jitsi STUN relay — fine for self-hosted-public-internet deployments. Set to your own coturn for a closed network."
  type        = string
  default     = "meet-jit-si-turnrelay.jitsi.net:443"
}

variable "enable_lobby" {
  description = "Whether the prosody lobby module is enabled. With lobby on, hosts admit guests one-by-one. Off matches Jitsi's classic \"anyone with the URL joins immediately\" behaviour."
  type        = bool
  default     = true
}

variable "enable_breakout_rooms" {
  description = "Whether the web UI exposes the breakout-rooms feature."
  type        = bool
  default     = true
}

variable "enable_prejoin_page" {
  description = "Whether participants see the audio/video preview screen before joining a room. Off skips straight into the call."
  type        = bool
  default     = true
}

variable "oidc_adapter_image_repo" {
  description = "Git URL the host clones to build the Jitsi OIDC adapter image. The adapter sits between Jitsi web and Authentik: it handles the OIDC dance, mints a Jitsi JWT, and redirects the user back into the room. Replace with your own fork if you've forked the adapter."
  type        = string
  default     = "https://github.com/sheyaln/jitsi-oidc-adapter.git"
}

variable "oidc_adapter_image_version" {
  description = "Git ref (tag, branch, or SHA) checked out from oidc_adapter_image_repo before building the local image. Default pinned to a tagged release; bump in lockstep with the adapter repo."
  type        = string
  default     = "v1.0.0"
}

variable "oidc_log_level" {
  description = "Log level for the OIDC adapter (DEBUG/INFO/WARNING/ERROR). DEBUG leaks tokens — only enable transiently."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.oidc_log_level)
    error_message = "oidc_log_level must be one of DEBUG, INFO, WARNING, ERROR."
  }
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default false."
  type        = bool
  default     = false
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/jitsi`. Use for named docker volumes, etc."
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

