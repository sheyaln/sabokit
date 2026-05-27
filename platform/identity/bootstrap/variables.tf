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

variable "credentials_preserve" {
  description = "In-place legacy cutover support. When true, skips generating new admin password, admin API token, and server secret_key, and reads existing values from the live `<secret_name_prefix>-admin` and `<secret_name_prefix>-server` Scaleway secrets via data sources. Without this, the first cutover apply collapses at Phase 3 because configure.sh exports the freshly-generated api_token as TF_VAR_authentik_admin_token while live Authentik still authenticates the legacy one. Drop the flag on next apply once cutover is verified. Short-lived knob, removal slated for v4.x."
  type        = bool
  default     = false
}

variable "credentials_preserve_source" {
  description = "Greenfield-to-v3 cutover support. Sibling to `credentials_preserve` (gated separately, both null/false by default). When non-null AND `credentials_preserve = false`, this object supplies canonical-key values directly to the admin + server Scaleway bags on first apply, instead of pulling them from pre-populated bags. Shape: `{ admin = { password, api_token }, server = { secret_key }, database = { password } }` — each sub-field is optional and falls back to the module's `random_*` value when omitted. The `database` sub-field is forwarded to the postgres_database submodule. Useful for migrating off a legacy Authentik install where the bootstrap admin password / API token live somewhere other than Scaleway Secret Manager. After the first apply, `ignore_changes = [data]` on the bag versions keeps the values pinned and the variable can be dropped (or flipped to `credentials_preserve = true`)."
  type = object({
    admin = optional(object({
      password  = optional(string)
      api_token = optional(string)
    }), {})
    server = optional(object({
      secret_key = optional(string)
    }), {})
    database = optional(object({
      password = optional(string)
    }), {})
  })
  default   = null
  sensitive = true
}
