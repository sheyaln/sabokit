# Application-tier composition variables.
#
# This layer self-discovers its `base` object (scaleway / compute / domains /
# authentik) from the infra + identity layers via the _shared/contract module (see
# main.tf) — there is no passed-in var.base and no remote_state. The
# inputs below split into two groups: the discovery config the contract needs
# (consumer-supplied, the same env-identity values infra got), and the
# per-service `any`-typed pass-through knobs (each bundle unpacks its own via
# try() against the upstream bundle defaults).

# ── Discovery config (forwarded to module.base) ──────────────────────────────

variable "org_slug" {
  description = "Org slug. With environment forms the <org>-<env> prefix every infra resource is discovered by."
  type        = string
}

variable "environment" {
  description = "Environment slug (e.g. prod, staging)."
  type        = string
}

variable "scaleway_project_id" {
  description = "Scaleway project ID."
  type        = string
}

variable "scaleway_region" {
  description = "Scaleway region (e.g. fr-par)."
  type        = string
}

variable "scaleway_zone" {
  description = "Scaleway zone (e.g. fr-par-1). Scopes the per-host instance lookups."
  type        = string
}

variable "private_network_subnet" {
  description = "VPC private-network CIDR. Config-known; the network ID itself is discovered."
  type        = string
  default     = null
}

variable "postgres_enabled" {
  description = "Whether infra provisioned the shared RDB instance."
  type        = bool
  default     = true
}

variable "postgres_engine" {
  description = "RDB engine string (e.g. PostgreSQL-15)."
  type        = string
  default     = ""
}

variable "base_domain" {
  description = "Primary domain."
  type        = string
}

variable "mgmt_domain" {
  description = "Management/ops domain. null defaults to base_domain."
  type        = string
  default     = null
}

variable "identity_domain" {
  description = "Authentik domain. null/empty defaults to auth.<base_domain>."
  type        = string
  default     = null
}

variable "smtp_secret_name" {
  description = "Name of the Scaleway secret infra (TEM) wrote with SMTP credentials. Empty leaves smtp_config_secret_id null."
  type        = string
  default     = "smtp-config"
}

variable "icon_base_url" {
  description = "App-icon CDN base. Empty resolves to the sabokit-assets default."
  type        = string
  default     = ""
}

variable "group_names" {
  description = "Names of every Authentik group an operations bundle might bind via authorized_groups (grafana/wazuh). Forwarded to module.base for discovery into base.authentik.groups."
  type        = list(string)
  default     = []
}

variable "compute_hosts" {
  description = "Consumer compute_hosts map (full shape). Projected to {role, ansible_group, ansible_groups} when forwarded to module.base; the sub-bundles read deployment hosts off base.compute.hosts."
  type        = any
}

# ── Per-app knobs (any-typed pass-through) ─────────────────────────────────────
# Per-app variable shape is documented in each bundle's variables.tf. All apps
# are gated by var.<app>.enabled (default false).

variable "outline" {
  description = "Outline bundle knobs. See platform/application/outline/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "steward" {
  description = "Steward bundle knobs. See platform/application/steward/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "vikunja" {
  description = "Vikunja bundle knobs. See platform/application/vikunja/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "bentopdf" {
  description = "Bentopdf bundle knobs. See platform/application/bentopdf/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "privacy_policy" {
  description = "Privacy Policy bundle knobs. See platform/application/privacy-policy/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "broadsheet" {
  description = "Broadsheet bundle knobs. See platform/application/broadsheet/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "nextcloud" {
  description = "Nextcloud bundle knobs. See platform/application/nextcloud/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "decidim" {
  description = "Decidim bundle knobs. See platform/application/decidim/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "jitsi" {
  description = "Jitsi bundle knobs. See platform/application/jitsi/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "espocrm" {
  description = "Espocrm bundle knobs. See platform/application/espocrm/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "n8n" {
  description = "N8N bundle knobs. See platform/application/n8n/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}

variable "backrest" {
  description = "Backrest bundle knobs. See platform/application/backrest/terraform/variables.tf. Off by default (enabled = false)."
  type        = any
  default     = {}
}
