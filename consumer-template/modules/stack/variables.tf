# Inputs the per-env caller passes through. Credentials are NOT here — they
# belong to the per-env root, not the shared stack module.

variable "scaleway_project_id" {
  description = "Scaleway project ID. All resources land in this project."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.scaleway_project_id))
    error_message = "scaleway_project_id must be a UUID (lowercase, hyphenated)."
  }
}

variable "scaleway_region" {
  description = "Scaleway region."
  type        = string
  default     = "fr-par"

  validation {
    condition     = contains(["fr-par", "nl-ams", "pl-waw"], var.scaleway_region)
    error_message = "scaleway_region must be one of: fr-par, nl-ams, pl-waw."
  }
}

variable "scaleway_zone" {
  description = "Scaleway zone for compute instances."
  type        = string
  default     = "fr-par-1"

  validation {
    condition     = can(regex("^(fr-par|nl-ams|pl-waw)-[123]$", var.scaleway_zone))
    error_message = "scaleway_zone must look like <region>-<digit>, e.g. fr-par-1, nl-ams-2."
  }
}

variable "org_slug" {
  description = "Short URL-safe slug used to name resources (e.g. \"acme\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.org_slug))
    error_message = "org_slug must be 3-32 chars, lowercase alphanumeric + hyphen, must start and end alphanumeric."
  }
}

variable "org_name" {
  description = "Organization display name shown in Authentik UI."
  type        = string

  validation {
    condition     = length(var.org_name) >= 1 && length(var.org_name) <= 100
    error_message = "org_name must be 1-100 characters."
  }
}

variable "environment" {
  description = "Short environment label (\"prod\", \"staging\", \"dev\")."
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,15}$", var.environment))
    error_message = "environment must be 1-16 chars, lowercase alphanumeric + hyphen, must start alphabetic."
  }
}

variable "base_domain" {
  description = "Primary apps domain (e.g. \"example.org\"). Must be registered + delegated to Scaleway DNS before apply."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.base_domain))
    error_message = "base_domain must be a valid DNS name (e.g. example.org)."
  }
}

variable "mgmt_domain" {
  description = "Management-apps domain. Defaults to base_domain (single-domain setup)."
  type        = string
  default     = null

  validation {
    condition     = var.mgmt_domain == null || can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.mgmt_domain == null ? "x.org" : var.mgmt_domain))
    error_message = "mgmt_domain must be null or a valid DNS name (e.g. ops.example.org)."
  }
}

variable "gateway_domain" {
  description = "Hostname Authentik is served at (e.g. \"auth.example.org\")."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.gateway_domain))
    error_message = "gateway_domain must be a valid DNS name (e.g. auth.example.org)."
  }
}

variable "infra_email" {
  description = "Operations contact email shown in Authentik notification bodies."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.infra_email))
    error_message = "infra_email must be a valid email address."
  }
}

variable "compute_hosts" {
  description = "Compute hosts to provision. Keyed by short host name."
  type = map(object({
    instance_type     = string
    image             = optional(string, "ubuntu_jammy")
    disk_size         = optional(number, 30)
    disk_type         = optional(string, "sbs_volume")
    role              = string
    ansible_group     = string
    ansible_groups    = optional(list(string), [])
    protected         = optional(bool, false)
    user_data         = optional(map(string), {})
    security_group_id = optional(string, null)
    tags              = optional(list(string), [])
  }))
  default = {
    apps = {
      instance_type = "DEV1-L"
      disk_size     = 100
      role          = "apps"
      ansible_group = "apps"
      protected     = true
    }
  }

  validation {
    condition     = length(var.compute_hosts) >= 1
    error_message = "compute_hosts must contain at least one host."
  }

  validation {
    condition     = alltrue([for k, _ in var.compute_hosts : can(regex("^[a-z][a-z0-9-]{0,30}$", k))])
    error_message = "compute_hosts keys must be lowercase alphanumeric + hyphen, max 31 chars, starting with a letter."
  }

  validation {
    condition     = alltrue([for _, h in var.compute_hosts : h.disk_size >= 10 && h.disk_size <= 10000])
    error_message = "compute_hosts.*.disk_size must be 10-10000 GB."
  }
}

variable "private_network_subnet" {
  description = "Private network CIDR (required when running managed PostgreSQL; a /22 is recommended)."
  type        = string
  default     = "10.0.0.0/22"

  validation {
    condition     = can(cidrhost(var.private_network_subnet, 0))
    error_message = "private_network_subnet must be a valid CIDR (e.g. 10.0.0.0/22)."
  }
}

variable "apps" {
  description = "Per-app enable flag and overrides. Each app has its own schema; see platform/apps/<name>/terraform/variables.tf. Includes `credentials_preserve` (in-place legacy cutover) and `credentials_preserve_source` (greenfield-to-v3 cutover; `map(string)`, sensitive) on every credential-generating bundle. The source map carries plaintext credentials — gitignore your tfvars or load from a Scaleway data source."
  type        = any
  default     = {}
  sensitive   = true
}

variable "base" {
  description = "Base-layer overrides (postgres, network, etc). Currently exposes `postgres_credentials_preserve` and `smtp_config_preserve` (bools) for in-place legacy cutover, plus `postgres_credentials_preserve_source` (`{ admin = string, databases = map(string) }`) for greenfield-to-v3 consumers supplying canonical postgres passwords directly. See platform/base/terraform/variables.tf."
  type        = any
  default     = {}
  sensitive   = true
}

variable "bootstrap" {
  description = "Bootstrap-tier bundles. Host services apps depend on at runtime (currently IMAP inbound via protonmail_bridge; future SMTP-relay providers slot in here). Sibling to var.apps but separated because these aren't user-facing apps. Each key is one provider — consumers pick ONE for any given capability; there's no abstract dispatcher (see platform/bootstrap/README.md). Per-provider input shapes live in platform/bootstrap/<provider>/terraform/variables.tf — the outer schema uses `any` for inner fields so per-provider knobs evolve without touching this contract."
  type = object({
    protonmail_bridge = optional(any, {})
  })
  default = {}
}

variable "identity" {
  description = "Identity-bundle inputs. Required fields: `tier_slots = list(object({ name, peers = map(string) }))` — the org's authority hierarchy as a DAG (lowest slot first, each peer_name → group_name). Optional fields: `extra_groups = map(object({ is_superuser, description }))` — additional Authentik groups beyond the tier_slots DAG; `icon_base_url` — where app icons are fetched from; `admin_group_name` / `member_group_name` / `delegate_group_name` / `delegate_role_name` — override the named-group pointers when the tier_slots DAG uses different group_names than the platform defaults (\"admin\" / \"member\" / \"delegate\"); `bootstrap_credentials_preserve` / `bootstrap_credentials_preserve_source` — cutover knobs for the identity_bootstrap module."
  type        = any
  sensitive   = true

  validation {
    condition     = try(length(var.identity.tier_slots), 0) >= 1
    error_message = "identity.tier_slots must contain at least one slot. Slots are processed lowest-privilege first."
  }

  validation {
    condition     = alltrue([for s in try(var.identity.tier_slots, []) : try(length(s.peers), 0) >= 1])
    error_message = "identity.tier_slots[*].peers must contain at least one peer_name → group_name entry per slot."
  }
}

variable "smtp_secret_name" {
  description = "Name of a Scaleway secret holding SMTP config {smtp_host, smtp_port, smtp_username, smtp_password}. Empty (default) disables outbound email — the identity flows still apply but every email step no-ops at runtime. Set to your secret name to turn email on; no re-create needed."
  type        = string
  default     = ""
}

# ── Gateway DNS ─────────────────────────────────────────────────────────────

variable "manage_gateway_dns" {
  description = "Create the gateway A record in Scaleway DNS during apply (default). Set false when DNS is hosted elsewhere (Cloudflare, Route53) or you want to manage it manually."
  type        = bool
  default     = true
}

variable "gateway_compute_host_key" {
  description = "Optional explicit key in compute_hosts whose public IP becomes the gateway A record. Null picks the first host with \"identity\" in ansible_groups, then any host with role=\"identity\", then the first host."
  type        = string
  default     = null
}

# ── Custom DNS records ──────────────────────────────────────────────────────

variable "custom_dns_records" {
  description = "Pass-through to base.custom_dns_records. Map of zone-name → list of records (A/AAAA/CNAME/MX/TXT/SRV). See platform/base/terraform/variables.tf for shape and examples."
  type        = any
  default     = {}
}
