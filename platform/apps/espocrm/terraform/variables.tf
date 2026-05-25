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
  description = "Full hostname EspoCRM is served at (e.g. \"crm.example.org\"). Never assembled from a subdomain prefix inside the module."
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
  description = "Optional icon path in Authentik media (e.g. \"espocrm-icon.png\")."
  type        = string
  default     = null
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

variable "auto_update_enabled" {
  description = "Whether the Watchtower platform bundle (if deployed) auto-pulls newer EspoCRM image versions. Default FALSE — EspoCRM customizations live in the database AND in `custom/` on a host bind mount; new image versions occasionally need post-upgrade DB rebuild + cache clear. Consumers bump image_tag explicitly so Ansible can run the upgrade steps."
  type        = bool
  default     = false
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
