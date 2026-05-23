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
  description = "Authentik portal category."
  type        = string
  default     = "Tools"
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
