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
  description = "Full hostname Postiz is served at (e.g. \"social.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category."
  type        = string
  default     = "Productivity"
}

variable "icon_url" {
  description = "Optional icon path in Authentik media (e.g. \"postiz-icon.png\")."
  type        = string
  default     = null
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"delegate\" — Postiz schedules posts to org-owned social accounts; the lowest tier shouldn't have access by default."
  type        = string
  default     = "delegate"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access Postiz beyond access_level. Map of role-name → group ID; keys MUST be static strings so the underlying for_each can plan even when group IDs are not yet known."
  type        = map(string)
  default     = {}
}

variable "tier_cascade_enabled" {
  description = "Whether to derive authorized_groups from the platform tier cascade (member→delegate→treasurer→admin; each tier inherits all lower tiers). Default true. Set false to use the primitive access_level + extra_authorized_groups path instead."
  type        = bool
  default     = true
}

variable "tier_access_level" {
  description = "Cascade tier required for baseline access. Users in this tier and any higher tier are admitted. Only consulted when tier_cascade_enabled = true. Default `delegate` — scheduling posts to org-owned social accounts is sensitive enough that the `member` tier shouldn't have access by default."
  type        = string
  default     = "delegate"
}

variable "monitoring_enabled" {
  description = "If true and a monitoring app is enabled, Postiz's log paths wire in. Postiz doesn't expose Prometheus metrics natively — scrape configs are empty."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to. The stack is heavy (~3GB RAM with elasticsearch + temporal + redis) — prefer a dedicated `apps` host with headroom."
  type        = string
  default     = "apps"
}

# ── Postiz-specific inputs ──────────────────────────────────────────────────

variable "image_tag" {
  description = "Postiz Docker image tag (ghcr.io/gitroomhq/postiz-app). Postiz publishes immutable date+sha tags alongside `latest`; pin one in production."
  type        = string
  default     = "latest"
}

variable "timezone" {
  description = "IANA timezone passed to the postiz container. Affects scheduling display + cron evaluation."
  type        = string
  default     = "UTC"
}

variable "smtp_from_email" {
  description = "From-address for transactional email (account activation, password reset, scheduled-post notifications). Empty disables SMTP — Postiz will not send mail. Wired via fc's smtp-config Scaleway secret when set."
  type        = string
  default     = ""
}

variable "social_platform_credentials" {
  description = <<-EOT
    Per-social-platform OAuth credentials Postiz uses to publish to each network. Map keyed by lowercase platform name; value is a map of env-var-name → value (Postiz uses inconsistent env names per platform — pass them through verbatim). Empty default = no platforms wired; Postiz silently omits the platform from the connect-account list. Consumer obtains each set out-of-band from the platform's developer console.

    Supported keys (and the env vars Postiz reads):
      x          = { X_URL, X_API_KEY, X_API_SECRET }
      linkedin   = { LINKEDIN_CLIENT_ID, LINKEDIN_CLIENT_SECRET }
      reddit     = { REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET }
      github     = { GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET }
      beehiiv    = { BEEHIIVE_API_KEY, BEEHIIVE_PUBLICATION_ID }
      threads    = { THREADS_APP_ID, THREADS_APP_SECRET }
      facebook   = { FACEBOOK_APP_ID, FACEBOOK_APP_SECRET }
      youtube    = { YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET }
      tiktok     = { TIKTOK_CLIENT_ID, TIKTOK_CLIENT_SECRET }
      pinterest  = { PINTEREST_CLIENT_ID, PINTEREST_CLIENT_SECRET }
      dribbble   = { DRIBBBLE_CLIENT_ID, DRIBBBLE_CLIENT_SECRET }
      discord    = { DISCORD_CLIENT_ID, DISCORD_CLIENT_SECRET, DISCORD_BOT_TOKEN_ID }
      slack      = { SLACK_ID, SLACK_SECRET, SLACK_SIGNING_SECRET }
      mastodon   = { MASTODON_URL, MASTODON_CLIENT_ID, MASTODON_CLIENT_SECRET }

    Unknown keys are passed through (Postiz adds platforms over time). Credentials land in the app-secrets Scaleway secret bag, not in plaintext on disk.
  EOT
  type        = map(map(string))
  default     = {}
  sensitive   = true
}

variable "disable_registration" {
  description = "Disables Postiz's built-in self-registration form. Default true — OIDC is the intended sign-in path, leaving registration open lets anyone with the URL create an account."
  type        = bool
  default     = true
}

variable "temporal_image_tag" {
  description = "Temporal auto-setup image tag. Postiz pins minor versions; bumping requires checking Postiz's docker-compose for compatibility."
  type        = string
  default     = "1.28.1"
}

variable "temporal_elasticsearch_image_tag" {
  description = "Elasticsearch image tag for temporal's visibility store. Temporal 1.28.x is built against ES 7.17.x; do not jump to 8.x without testing."
  type        = string
  default     = "7.17.27"
}

variable "temporal_postgres_image_tag" {
  description = "Postgres image tag for temporal's metadata store. Kept in-stack (not Scaleway RDB) — it's a glorified workflow log, not user data."
  type        = string
  default     = "16"
}

variable "memory_limit" {
  description = "Memory limit for the postiz container itself (NextJS + NestJS combined image). The sidecars (redis, temporal, ES, temporal-pg) carry their own limits inside the role's defaults."
  type        = string
  default     = "1G"
}

variable "memory_reservation" {
  description = "Memory reservation for the postiz container."
  type        = string
  default     = "512M"
}

variable "cpu_limit" {
  description = "CPU limit for the postiz container."
  type        = string
  default     = "1.0"
}

variable "cpu_reservation" {
  description = "CPU reservation for the postiz container."
  type        = string
  default     = "0.25"
}

variable "es_heap_size" {
  description = "JVM heap size for the elasticsearch container temporal uses for workflow visibility. ES is the heaviest sidecar in the stack — keep this small (~256m) unless workflow volume justifies it."
  type        = string
  default     = "256m"
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up Postiz host-side state. Default true — local uploads volume + temporal postgres data live on the host and would be lost on host loss."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond the defaults (`/backup-sources/opt/postiz`, the `postiz-uploads`, `postiz-config`, and `temporal-postgres-data` named volumes). The redis cache + the elasticsearch index are intentionally excluded — both are reconstructible."
  type        = list(string)
  default     = []
}

variable "backup_schedule_cron" {
  description = "Backrest cron (6-field, seconds first) for Postiz's plan. Default 02:00 UTC daily."
  type        = string
  default     = "0 0 2 * * *"
}

variable "backup_retention" {
  description = "Restic retention policy for Postiz's backup plan."
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

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle (if deployed) auto-pulls newer Postiz image versions. Default true — Postiz publishes frequently and tracks `latest` aggressively. Pin image_tag in prod if you'd rather control upgrades manually."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts Postiz when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

# TODO(v3): Postiz upstream has an open PR (gitroomhq/postiz-app#1124) adding
# generic-S3 storage support (STORAGE_PROVIDER="s3" + S3_ENDPOINT). When it
# lands, add `storage_provider`/`storage_bucket_*` vars + a scaleway_object_bucket
# block so consumers can move uploads off the host disk. Until then the bundle
# is local-filesystem only and the uploads volume is the source of truth.
