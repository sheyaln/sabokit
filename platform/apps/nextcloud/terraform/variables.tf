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

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Files"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"nextcloud-icon.png\")."
  type        = string
  default     = null
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

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle (if deployed) auto-pulls newer Nextcloud image versions. Default FALSE — Nextcloud only supports one-major-at-a-time upgrades and major bumps require post-upgrade occ steps. Consumers should bump image_tag explicitly and let Ansible handle the upgrade path."
  type        = bool
  default     = false
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
