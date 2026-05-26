# Inputs the per-env caller passes through. Credentials are NOT here — they
# belong to the per-env root, not the shared stack module.

variable "scaleway_project_id" {
  description = "Scaleway project ID. All resources land in this project."
  type        = string
}

variable "scaleway_region" {
  description = "Scaleway region."
  type        = string
  default     = "fr-par"
}

variable "scaleway_zone" {
  description = "Scaleway zone for compute instances."
  type        = string
  default     = "fr-par-1"
}

variable "org_slug" {
  description = "Short URL-safe slug used to name resources (e.g. \"acme\")."
  type        = string
}

variable "org_name" {
  description = "Organization display name shown in Authentik UI."
  type        = string
}

variable "environment" {
  description = "Short environment label (\"prod\", \"staging\", \"dev\")."
  type        = string
  default     = "prod"
}

variable "base_domain" {
  description = "Primary apps domain (e.g. \"example.org\"). Must be registered + delegated to Scaleway DNS before apply."
  type        = string
}

variable "mgmt_domain" {
  description = "Management-apps domain. Defaults to base_domain (single-domain setup)."
  type        = string
  default     = null
}

variable "gateway_domain" {
  description = "Hostname Authentik is served at (e.g. \"auth.example.org\")."
  type        = string
}

variable "infra_email" {
  description = "Operations contact email shown in Authentik notification bodies."
  type        = string
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
}

variable "private_network_subnet" {
  description = "Private network CIDR (required when running managed PostgreSQL; a /22 is recommended)."
  type        = string
  default     = "10.0.0.0/22"
}

variable "apps" {
  description = "Per-app enable flag and overrides. Each app has its own schema; see platform/apps/<name>/terraform/variables.tf."
  type        = any
  default     = {}
}

variable "base" {
  description = "Base-layer overrides (postgres, network, etc). Currently exposes `postgres_credentials_preserve` (bool) for in-place legacy cutover. See platform/base/terraform/variables.tf."
  type        = any
  default     = {}
}

variable "bootstrap" {
  description = "Bootstrap-tier bundles. Map of {<bundle> = { enabled = bool, ... }}. Currently houses protonmail_bridge (IMAP inbound mail). Sibling to var.apps but separated because these are host services apps depend on rather than user-facing apps. See platform/bootstrap/<bundle>/terraform/variables.tf for per-bundle inputs."
  type        = any
  default     = {}
}

variable "identity" {
  description = "Identity-bundle inputs. Required fields: `tier_slots = list(object({ name, peers = map(string) }))` — the org's authority hierarchy as a DAG (lowest slot first, each peer_name → group_name). Optional fields: `extra_groups = map(object({ is_superuser, description }))` — additional Authentik groups beyond the tier_slots DAG; `icon_base_url` — where app icons are fetched from."
  type        = any
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
