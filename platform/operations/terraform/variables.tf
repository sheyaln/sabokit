# Operations-tier composition variables.
#
# This layer self-discovers its `base` object (scaleway / compute / domains /
# authentik) from the infra + identity layers via the _shared/contract module
# (see main.tf) — there is no passed-in var.base and no remote_state. The
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

# ── Per-service knobs (any-typed pass-through) ───────────────────────────────
# Per-service variable shape is documented in each bundle's variables.tf.

variable "loki" {
  description = "Loki bundle knobs. See platform/operations/loki/terraform/variables.tf. Defaults to {enabled = true}."
  type        = any
  default     = {}
}

variable "prometheus" {
  description = "Prometheus bundle knobs. See platform/operations/prometheus/terraform/variables.tf. Defaults to {enabled = true}."
  type        = any
  default     = {}
}

variable "grafana" {
  description = "Grafana bundle knobs. See platform/operations/grafana/terraform/variables.tf. Defaults to {enabled = true}."
  type        = any
  default     = {}
}

variable "wazuh" {
  description = "Wazuh-manager bundle knobs. See platform/operations/wazuh/terraform/variables.tf. Defaults to {enabled = true}."
  type        = any
  default     = {}
}

variable "protonmail_bridge" {
  description = "ProtonMail Bridge (IMAP gateway apps fetch mail through). See platform/operations/protonmail-bridge/terraform/variables.tf. OFF by default; set enabled + imap_username + bridge_login_secret_id to turn on."
  type        = any
  default     = {}
}
