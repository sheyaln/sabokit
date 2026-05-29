# Inputs are entirely config-known values the consumer already declares per
# layer (org/env, region/zone, domains, the tier DAG, the host roster). The
# module turns those into the live `base` object by discovering everything
# infra + identity provisioned — by name/tag, never via remote_state.

variable "org_slug" {
  description = "Org slug. With environment forms the <org>-<env> name prefix every infra resource is tagged/named with."
  type        = string
}

variable "environment" {
  description = "Environment slug (e.g. prod, staging)."
  type        = string
}

variable "scaleway_project_id" {
  description = "Scaleway project ID. Surfaced verbatim in base.scaleway.project_id."
  type        = string
}

variable "scaleway_region" {
  description = "Scaleway region (e.g. fr-par). Surfaced in base.scaleway.region and used to build the S3 endpoint."
  type        = string
}

variable "scaleway_zone" {
  description = "Scaleway zone (e.g. fr-par-1). Surfaced in base.scaleway.zone and used to scope the per-host instance lookups."
  type        = string
}

variable "private_network_subnet" {
  description = "VPC private-network CIDR. Config-known; surfaced verbatim (the network ID itself is discovered)."
  type        = string
  default     = null
}

variable "postgres_enabled" {
  description = "Whether infra provisioned the shared RDB instance. When false the postgres_* fields resolve to null and no RDB lookup runs."
  type        = bool
  default     = true
}

variable "postgres_engine" {
  description = "RDB engine string (e.g. PostgreSQL-15). Config-known; surfaced verbatim."
  type        = string
  default     = ""
}

variable "compute_hosts" {
  description = "Per-host ansible-targeting config keyed by host_key — the role/ansible_group/ansible_groups the compute output carries. The layer root projects its full consumer compute_hosts map down to this subset (object types reject extra attributes). role must match the role tag infra applied, since the host instance + its role SG are discovered by the <org>-<env>-<key>/<role> naming."
  type = map(object({
    role           = string
    ansible_group  = optional(string, "")
    ansible_groups = optional(list(string), [])
  }))
}

variable "base_domain" {
  description = "Primary domain. Surfaced in base.domains.base_domain and used as the identity_domain/mgmt_domain fallback."
  type        = string
}

variable "mgmt_domain" {
  description = "Management/ops domain. null defaults to base_domain (mirrors infra's locals)."
  type        = string
  default     = null
}

variable "identity_domain" {
  description = "Authentik domain. null/empty defaults to auth.<base_domain> (mirrors infra's locals)."
  type        = string
  default     = null
}

variable "smtp_secret_name" {
  description = "Name of the Scaleway secret infra (TEM) wrote with SMTP credentials. Empty skips the lookup and leaves smtp_config_secret_id null."
  type        = string
  default     = "smtp-config"
}

variable "icon_base_url" {
  description = "App-icon CDN base. Empty resolves to the sabokit-assets master default (mirrors identity's effective_icon_base_url)."
  type        = string
  default     = ""
}

variable "tier_slots" {
  description = "The identity tier DAG, same shape identity consumes: ordered list of { name, peers = map(peer_name -> group_name) }, lowest privilege first. Config-known — drives both which groups to discover and the tier_cascade recompute."
  type = list(object({
    name  = string
    peers = map(string)
  }))
}

variable "extra_group_names" {
  description = "Names of the non-cascade platform groups identity created from its extra_groups input (service-account scopes, org roles). Discovered by name and merged into base.authentik.groups, but excluded from the tier_cascade."
  type        = list(string)
  default     = []
}
