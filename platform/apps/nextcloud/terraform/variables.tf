# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, the bundle skips `random_password` generation for every secret in the `nextcloud-app-secrets` bag (admin bootstrap password, Redis password, OnlyOffice JWT + secure link, Talk turn/signaling/internal secrets) and reads each value from the live bag via a data source. Also passed through to OIDC and database submodules. Drop after cutover; short-lived, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "base" {
  description = "Outputs from module \"base\". Apps consume { scaleway, authentik, compute, domains } from this. Shape documented in /ARCHITECTURE.md (\"What base/ outputs\")."
  type        = any
}

variable "hostname" {
  description = "Full hostname Nextcloud is served at (e.g. \"cloud.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "onlyoffice_hostname" {
  description = "Full hostname OnlyOffice Document Server is served at (e.g. \"docs.example.org\"). The browser loads the editor from this URL, so it must be reachable from clients. Required when enabled."
  type        = string
  default     = ""
}

variable "talk_hostname" {
  description = "Full hostname Talk HPB signaling is served at over WSS (e.g. \"talk.example.org\"). The same DNS name must publicly resolve to the host because clients also reach the eturnal TURN server at this name on UDP/TCP 3478. Required when enabled."
  type        = string
  default     = ""
}

variable "dns_zone_override" {
  description = "Override the DNS zone all three A records (nextcloud, onlyoffice, talk) land in. Default empty derives each zone independently from its hostname by longest-suffix match against var.base.domains.zones. Set explicitly only for edge cases where derivation produces the wrong zone — applies to all three hostnames uniformly."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Files"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "Nextcloud"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`nextcloud`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "nextcloud-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"member\"."
  type        = string
  default     = "member"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Nextcloud beyond access_level. Map of role-name → group ID; keys MUST be static strings (e.g. \"delegate\", \"manager\") so the underlying for_each can plan even when group IDs are not yet known."
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
  description = "If true and a monitoring app is enabled, Nextcloud's log paths wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to (e.g. \"apps\", \"tools\"). The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── Nextcloud-specific inputs ───────────────────────────────────────────────

variable "image_tag" {
  description = "Nextcloud Docker image tag. Pin to a major version (e.g. \"32-apache\") rather than \"latest\" — Nextcloud only supports one-major-at-a-time upgrades."
  type        = string
  default     = "32-apache"
}

variable "admin_username" {
  description = "Bootstrap admin username created on first install. OIDC users sign in separately; this account is the fallback if OIDC is misconfigured."
  type        = string
  default     = "ncadmin"
}

variable "instance_name" {
  description = "User-facing instance name (browser tab, email headers, mobile clients). Default \"Nextcloud\" — set to your org's product name (e.g. \"Acme Cloud\") for branded deployments."
  type        = string
  default     = "Nextcloud"
}

variable "maintenance_window_start" {
  description = "UTC hour (0-23) when Nextcloud runs its nightly background-job window. 2 = 2 AM UTC. Pick a low-traffic hour for your user base."
  type        = number
  default     = 2
  validation {
    condition     = var.maintenance_window_start >= 0 && var.maintenance_window_start <= 23
    error_message = "maintenance_window_start must be in [0, 23]."
  }
}

variable "enabled_apps" {
  description = "Nextcloud apps the post-install script auto-installs and enables on every run. Default set turns Nextcloud into a full collaboration suite (group folders, push, notes, tasks, forms, polls, epub reader, webhooks). Override to keep the install lean or add your own (e.g. \"deck\", \"calendar\", \"contacts\")."
  type        = list(string)
  default = [
    "groupfolders",
    "notify_push",
    "notes",
    "tasks",
    "forms",
    "polls",
    "epubviewer",
    "webhook_listeners",
  ]
}

variable "disabled_apps" {
  description = "Nextcloud apps the post-install script disables on every run. Default disables `photos` because the thumbnail jobs are heavy and most consumers don't actively use the photos surface."
  type        = list(string)
  default     = ["photos"]
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Nextcloud when its healthcheck fails. Default true — restart-on-unhealthy is safe; the bigger concern is the upgrade path, not unhealthy state recovery."
  type        = bool
  default     = true
}

variable "n8n_form_webhook_url" {
  description = "Optional: URL of an n8n webhook receiver for Nextcloud Forms submissions. When non-empty, the post-install script registers a webhook_listeners hook for `OCA\\Forms\\Events\\FormSubmittedEvent` pointed at this URL (idempotent). Requires `webhook_listeners` in `enabled_apps`."
  type        = string
  default     = ""
}

variable "default_phone_region" {
  description = "ISO 3166-1 alpha-2 country code used by Nextcloud to format phone numbers when no region is supplied (e.g. \"US\", \"DE\", \"FR\")."
  type        = string
  default     = "US"
}

variable "max_upload_size_bytes" {
  description = "Largest file Nextcloud accepts via upload. Default 2147483648 = 2 GiB. The Apache body limit is set to match."
  type        = number
  default     = 2147483648
}

variable "trusted_proxies" {
  description = "CIDR block trusted as a reverse proxy. Defaults to the Docker bridge range so Traefik's X-Forwarded-* headers are honoured. Override to a tighter CIDR if traffic enters Nextcloud through a non-Docker proxy."
  type        = string
  default     = "172.16.0.0/12"
}

variable "smtp_from_email" {
  description = "From: address used by Nextcloud for transactional email (e.g. \"cloud@example.org\"). Empty disables SMTP. SMTP host/port/username/password come from the platform-wide smtp-config secret looked up by the Ansible role."
  type        = string
  default     = ""
}

# ── OnlyOffice-specific inputs ──────────────────────────────────────────────

variable "onlyoffice_image_tag" {
  description = "OnlyOffice Document Server Docker image tag. Bumping versions is generally safe; the server stores no editable state outside the postgres bundled in its image."
  type        = string
  default     = "latest"
}

variable "onlyoffice_memory_limit" {
  description = "Memory ceiling for the OnlyOffice Document Server container. Document conversions are RAM-hungry; below ~1.5G large files OOM mid-edit."
  type        = string
  default     = "2G"
}

variable "onlyoffice_cpu_limit" {
  description = "CPU ceiling for the OnlyOffice Document Server container."
  type        = string
  default     = "2.0"
}

# ── Talk HPB-specific inputs ────────────────────────────────────────────────

variable "talk_image_tag" {
  description = "Tag for the ghcr.io/nextcloud-releases/aio-talk image. The AIO image bundles eturnal (TURN/STUN), Janus, and the signaling server; treat it as one moving target."
  type        = string
  default     = "latest"
}

variable "talk_turn_port" {
  description = "Public TCP/UDP port for the bundled eturnal TURN server. 3478 is the IANA TURN port and what Talk clients try first. Change only when the host already binds 3478."
  type        = number
  default     = 3478
}

variable "talk_relay_port_min" {
  description = "Lower bound of the UDP port range eturnal allocates for media relay. Together with talk_relay_port_max this defines the host ports that MUST be open in the security group for video to flow."
  type        = number
  default     = 49152
}

variable "talk_relay_port_max" {
  description = "Upper bound of the UDP relay range. Keep this tight (default 49152-49252 = 101 ports) — every concurrent call needs a handful of ports, not thousands."
  type        = number
  default     = 49252
}

variable "talk_memory_limit" {
  description = "Memory ceiling for the Talk HPB container. The bundled Janus + signaling are light; eturnal is also light. 1G is comfortable for small org video."
  type        = string
  default     = "1G"
}

variable "talk_cpu_limit" {
  description = "CPU ceiling for the Talk HPB container. WebRTC media doesn't pass through the HPB once peers are connected; the SFU only touches each packet briefly."
  type        = string
  default     = "1.0"
}

variable "storage_class" {
  description = "Scaleway storage class the primary-storage bucket transitions objects to. Default `STANDARD` (Multi-AZ) is correct for Nextcloud — every user file lives here and is read on every download. `ONEZONE_IA` saves storage cost at the price of single-AZ durability; sensible only for buckets dominated by archival uploads. `GLACIER` is wrong — read latency kills the UX."
  type        = string
  default     = "STANDARD"
}

variable "storage_class_transition_days" {
  description = "Days after upload before objects move to `storage_class`. Only consulted when storage_class != STANDARD."
  type        = number
  default     = 1
}

variable "bucket_name_override" {
  description = "Override the Scaleway object bucket name. Defaults to '$${secrets_namespace}-nextcloud-data'. Set to match an existing legacy bucket to enable in-place import without force-replace + data loss. ONLY the bucket name flips — IAM apps, secret names, etc. keep using the canonical slug. SHORT-LIVED: rsync data into the canonical naming pattern within a release cycle and drop this override; the knob is marked for removal in v4.0."
  type        = string
  default     = ""
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/nextcloud`. Use for named docker volumes, etc."
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
