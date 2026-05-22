# ── Scaleway credentials (consumer-managed, never committed) ────────────────

variable "scaleway_access_key" {
  description = "Scaleway access key. Pass via TF_VAR_scaleway_access_key or terraform.tfvars (gitignored)."
  type        = string
  sensitive   = true
}

variable "scaleway_secret_key" {
  description = "Scaleway secret key."
  type        = string
  sensitive   = true
}

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

# ── Authentik admin token ───────────────────────────────────────────────────

variable "authentik_admin_token" {
  description = "Authentik admin API token. Created in Authentik UI under Directory > Tokens. Required to provision applications, providers, groups."
  type        = string
  sensitive   = true
}

# ── Organization identity ───────────────────────────────────────────────────

variable "org_slug" {
  description = "Short URL-safe slug used to name resources (e.g. \"acme\")."
  type        = string
}

variable "environment" {
  description = "Short environment label (\"prod\", \"staging\", \"dev\")."
  type        = string
  default     = "prod"
}

# ── Domains ─────────────────────────────────────────────────────────────────

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
  description = "Hostname Authentik is served at (e.g. \"auth.example.org\"). Must be reachable for the authentik provider."
  type        = string
}

# ── Compute topology ────────────────────────────────────────────────────────

variable "compute_hosts" {
  description = "Compute hosts to provision. Keyed by short host name."
  type = map(object({
    instance_type     = string
    image             = optional(string, "ubuntu_jammy")
    disk_size         = optional(number, 30)
    disk_type         = optional(string, "sbs_volume")
    role              = string
    ansible_group     = string
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

# ── App enable/disable + per-app config ─────────────────────────────────────

variable "apps" {
  description = "Per-app enable flag and overrides. Each app has its own schema; see apps/<name>/variables.tf for what each accepts."
  type        = any
  default     = {}
}
