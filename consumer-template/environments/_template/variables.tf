# Per-env variables. These VARY between envs (staging vs prod) and live in
# `terraform.tfvars` (gitignored — copy from `terraform.tfvars.example`).
# Persistent infrastructure shape lives in `config.tf` (committable).
#
# Convention: anything that changes between envs goes here. Things that
# don't change — the apps catalog, host topology shape, tier_slots, org
# identity — stay in config.tf.

# ── Runtime credentials (env vars only) ─────────────────────────────────────
# Never set these in terraform.tfvars — they're supplied via env:
#   SCW_ACCESS_KEY / SCW_SECRET_KEY (or TF_VAR_scaleway_access_key /
#   TF_VAR_scaleway_secret_key). _lib.sh re-exports them as SCW_* so the
#   provider sees a single credential source.

variable "scaleway_access_key" {
  type      = string
  sensitive = true
}

variable "scaleway_secret_key" {
  type      = string
  sensitive = true
}

variable "authentik_admin_token" {
  description = "Authentik admin API token. Empty during the first-phase apply (when Authentik doesn't exist yet); configure.sh fetches it from the bootstrap admin secret and re-exports as TF_VAR_authentik_admin_token before the second phase."
  type        = string
  sensitive   = true
  default     = ""
}

# ── Scaleway project + region (vary per env) ────────────────────────────────

variable "scaleway_project_id" {
  description = "Scaleway project UUID. Different between staging and prod."
  type        = string
}

variable "scaleway_region" {
  description = "Scaleway region (e.g. fr-par)."
  type        = string
  default     = "fr-par"
}

variable "scaleway_zone" {
  description = "Scaleway availability zone (e.g. fr-par-1)."
  type        = string
  default     = "fr-par-1"
}

# ── Env identity + contact (vary per env) ───────────────────────────────────

variable "environment" {
  description = "Env name (e.g. prod, staging). Matches the env directory name."
  type        = string
}

variable "base_domain" {
  description = "Public base domain for this env (e.g. example.org for prod, staging.example.org for staging). App hostnames in config.tf interpolate against this."
  type        = string
}

variable "gateway_domain" {
  description = "Authentik gateway domain (e.g. auth.example.org). Read by preflight.sh + up.sh from terraform.tfvars; keep at top-level `key = \"value\"` shape so the shell helpers can awk it out."
  type        = string
}

variable "mgmt_domain" {
  description = "Management subdomain. Empty (default) collapses to base_domain. Override only if you maintain a separate management zone (e.g. ops.example.org)."
  type        = string
  default     = ""
}

variable "infra_email" {
  description = "Operations contact email. Surfaces in Let's Encrypt ACME registration + Authentik UI strings."
  type        = string
}

# ── Compute sizing (varies per env) ─────────────────────────────────────────

variable "compute_instance_types" {
  description = "Per-host instance type. Staging typically smaller than prod. Keys must match `compute_hosts` in config.tf."
  type = object({
    tools      = string
    identity   = string
    management = string
  })
  default = {
    tools      = "DEV1-L"
    identity   = "DEV1-M"
    management = "DEV1-M"
  }
}

variable "compute_disk_sizes" {
  description = "Per-host disk size in GB. Same key shape as compute_instance_types."
  type = object({
    tools      = number
    identity   = number
    management = number
  })
  default = {
    tools      = 100
    identity   = 30
    management = 60
  }
}

# ── Network (rarely varies, but per-env when it does) ───────────────────────

variable "private_network_subnet" {
  description = "Private network CIDR for this env. /22 recommended."
  type        = string
  default     = "10.0.0.0/22"
}
