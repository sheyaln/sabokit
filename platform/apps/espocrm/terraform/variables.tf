# ── Contract inputs (every app bundle has these) ────────────────────────────

variable "enabled" {
  description = "Master toggle. When false the bundle provisions zero resources."
  type        = bool
  default     = false
}

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, the bundle skips `random_password.admin` (EspoCRM admin fallback password) and reads ADMIN_PASSWORD from the live `espocrm-app-secrets` bag via a data source. Also passed through to OIDC and database submodules. Drop after cutover; short-lived, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "credentials_preserve_source" {
  description = "Greenfield-to-v3 cutover support. Sibling to `credentials_preserve` (gated separately, both null/false by default). When non-null AND `credentials_preserve = false`, this map supplies canonical keys directly into the bundle's `<slug>-app-secrets` Scaleway bag on the first apply instead of pulling them from a pre-populated one. Schema (canonical keys this bundle reads): `ADMIN_PASSWORD`. Supply only the keys you want to seed; any not supplied fall back to the bundle's generated `random_password` values. Only covers the bundle's own app-secrets bag — OIDC and database credentials are handled by their own preserve paths on the inner submodules. After the first apply, `ignore_changes = [data]` on the bag version keeps the values pinned and the variable can be dropped (or flipped to `credentials_preserve = true`). The map is plaintext in consumer TF — put it behind a Scaleway data source or a gitignored file."
  type        = map(string)
  default     = null
  sensitive   = true
}

variable "base" {
  description = "Outputs from module \"base\". Apps consume { scaleway, authentik, compute, domains } from this. Shape documented in /ARCHITECTURE.md (\"What base/ outputs\")."
  type        = any
}

variable "hostname" {
  description = "Full hostname EspoCRM is served at (e.g. \"crm.example.org\"). Never assembled from a subdomain prefix inside the module."
  type        = string
  default     = ""
}

variable "dns_zone_override" {
  description = "Override the DNS zone the per-app A record lands in. Default empty derives the zone from var.hostname by longest-suffix match against var.base.domains.zones. Set explicitly only for edge cases where derivation produces the wrong zone."
  type        = string
  default     = ""
}

variable "category_group" {
  description = "Authentik portal category. Default 'Administration' — CRM is where org admins manage member data (same bucket as steward); override per-consumer if your portal taxonomy puts it elsewhere."
  type        = string
  default     = "Administration"
}

variable "application_name" {
  description = "Display name for the bundle's Authentik application (shown in the portal + admin UI). Default matches the bundle's stock name; override per-consumer for branded portal entries (e.g. \"Sabo Cloud Provider\" instead of \"Nextcloud\")."
  type        = string
  default     = "CRM (EspoCRM)"
}

variable "application_slug" {
  description = "Override the Authentik application's slug. Defaults to the bundle's stock slug (`espocrm`). Set to match an existing legacy slug to enable in-place state import without force-replace. Note: this overrides ONLY the Authentik application's slug — bucket names, secret names, IAM apps and other internal namespaces keep using the canonical bundle slug."
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
  default     = "espocrm-icon.png"
}

variable "access_level" {
  description = "Key in base.authentik.groups granting baseline access. Defaults to \"member\"."
  type        = string
  default     = "member"
}

variable "extra_authorized_groups" {
  description = "Additional Authentik groups allowed to access EspoCRM beyond access_level. Map of role-name → group ID; keys MUST be static strings (e.g. \"delegate\", \"treasurer\") so the underlying for_each can plan even when group IDs are not yet known."
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
  description = "If true and a monitoring app is enabled, EspoCRM's log paths + Traefik dashboard wire in. No effect when monitoring apps are disabled."
  type        = bool
  default     = true
}

variable "deployment_host_key" {
  description = "Key in base.compute.hosts identifying the VM this app deploys to (e.g. \"apps\", \"tools\"). The Ansible playbook targets this host's ansible_group."
  type        = string
  default     = "apps"
}

# ── EspoCRM-specific inputs ─────────────────────────────────────────────────

variable "image_tag" {
  description = "EspoCRM Docker image tag."
  type        = string
  default     = "latest"
}

variable "diun_watch_enabled" {
  description = "Whether Diun watches this app's containers for upstream image updates. When true (default) the bundle emits a `diun.enable=true` label on each compose service, opting it into the platform Diun bundle's registry polling. Flip false to silence notifications for this app."
  type        = bool
  default     = true
}

variable "autoheal_enabled" {
  description = "Whether the Autoheal platform bundle (if deployed) restarts EspoCRM when its healthcheck fails. Default true."
  type        = bool
  default     = true
}

variable "timezone" {
  description = "IANA timezone applied to the EspoCRM runtime config and the container's TZ."
  type        = string
  default     = "UTC"
}

variable "admin_username" {
  description = "Username for the local admin account created on first boot. Used only when OIDC is unreachable (fallback sign-in)."
  type        = string
  default     = "admin"
}

variable "b2c_mode" {
  description = "Whether to enable EspoCRM's \"Business to Consumer\" mode (simplifies the UI for orgs that don't track companies/accounts). Default true matches the constituent-management use case; flip to false for traditional sales-CRM deployments."
  type        = bool
  default     = true
}

variable "oidc_username_claim" {
  description = "OIDC claim used as the EspoCRM username (e.g. \"email\", \"preferred_username\")."
  type        = string
  default     = "email"
}

variable "oidc_group_claim" {
  description = "OIDC claim that carries the user's group memberships. Used by EspoCRM's group-to-role mapping."
  type        = string
  default     = "groups"
}

variable "oidc_team_id_prefix" {
  description = "Prefix prepended to Authentik group names when auto-creating EspoCRM teams. Keeps SSO-managed teams visually separated from hand-curated ones. Empty string disables prefixing."
  type        = string
  default     = "sso-"
}

variable "oidc_group_role_mapping" {
  description = "Optional map of Authentik group name → EspoCRM role name. EspoCRM's OIDC handler assigns the matching role on login. Roles must exist in EspoCRM (either built-in or provisioned via the member-entity bootstrap)."
  type        = map(string)
  default     = {}
}

variable "enable_member_entity_bootstrap" {
  description = "Whether to render and run the Member/DuesPayment custom-entity bootstrap. Opt-in because it shapes the CRM around constituent/dues tracking — orgs using EspoCRM as a generic sales CRM should leave this off."
  type        = bool
  default     = false
}

variable "member_entity_webhooks" {
  description = "Optional list of webhook definitions installed against the Member entity. Each entry: { id, name, event, type, field, url }. Empty list = no webhooks. The Ansible bootstrap upserts these into EspoCRM's webhook table; orgs typically point url at an internal automation hook (e.g. n8n)."
  type = list(object({
    id    = string
    name  = string
    event = string
    type  = optional(string, "create")
    field = optional(string, null)
    url   = string
  }))
  default = []
}

variable "smtp_from_email" {
  description = "From: address for EspoCRM transactional email. Empty disables SMTP. Set explicitly (e.g. \"crm@example.org\") when an SMTP secret exists in base."
  type        = string
  default     = ""
}

variable "backup_enabled" {
  description = "Whether the Backrest platform bundle (if deployed on the same host) backs up this app's host-side state. Default true."
  type        = bool
  default     = true
}

variable "backup_extra_paths" {
  description = "Additional restic paths beyond `/backup-sources/opt/espocrm`. Use for named docker volumes, etc."
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
