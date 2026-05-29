variable "org_slug" {
  description = "Short URL-safe slug used to namespace Scaleway secrets (e.g. \"acme\")."
  type        = string
}

variable "environment" {
  description = "Short environment label (\"prod\", \"staging\", \"dev\"). Used in secret names and tags."
  type        = string
}

variable "infra_email" {
  description = "Email address for the bootstrap admin user. Authentik creates the admin account on first boot with this email."
  type        = string
}

variable "postgres_instance_id" {
  description = "Scaleway managed PostgreSQL instance ID. Typically base.scaleway.postgres_instance_id."
  type        = string
}

variable "postgres_endpoint" {
  description = "Private-network endpoint of the PostgreSQL instance. Object {ip, port}. Typically base.scaleway.postgres_endpoint."
  type = object({
    ip   = string
    port = number
  })
}

variable "postgres_engine" {
  description = "PostgreSQL engine identifier (e.g. \"PostgreSQL-16\"). Typically base.scaleway.postgres_engine."
  type        = string
}

variable "tags" {
  description = "Extra tags applied to every Scaleway secret created by this module. The module always adds [\"authentik\", \"identity\", var.environment]."
  type        = list(string)
  default     = []
}

variable "admin_username" {
  description = "Authentik admin username stored in the secret JSON for reference. Note that Authentik itself uses AUTHENTIK_BOOTSTRAP_USER or the default \"akadmin\" — this field is informational only."
  type        = string
  default     = "akadmin"
}

variable "media_s3_secret_id" {
  description = "Scaleway secret ID for Authentik media-storage S3 credentials. Empty disables — Authentik falls back to filesystem media. Operators provision the secret out-of-band (it carries Scaleway access keys); this module just plumbs the ID through to the authentik-server ansible role."
  type        = string
  default     = ""
}

variable "smtp_secret_id" {
  description = "Scaleway secret ID for Authentik SMTP credentials. Empty disables outbound email — auth flows still apply but every email step no-ops. Provisioned out-of-band like media_s3_secret_id."
  type        = string
  default     = ""
}

variable "authentik_version" {
  description = "Authentik image tag to pin (e.g. \"2025.12.1\"). Not a secret — surfaced verbatim in the identity_bootstrap output and wired to the authentik-server Ansible role's authentik_version. Empty (default) defers to the role's pinned default (the version this blueprint release was validated against). Authentik has breaking inter-release DB migrations; set this deliberately and read the upstream release notes before bumping."
  type        = string
  default     = ""
}

