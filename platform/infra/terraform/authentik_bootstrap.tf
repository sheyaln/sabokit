# Authentik's logical DB + bootstrap secrets — the root-of-trust exception.
#
# Per V1.0-PLAN: infra owns Authentik's DB + admin/server/bootstrap-token
# secrets, even though identity owns everything else Authentik. The reason is
# apply-order: Authentik's container boots in the MIDDLE of the identity layer
# (ansible), between "DB must exist" and "configure via TF". If identity owned
# the DB its scaleway-TF would run before its ansible and its authentik-TF
# after — a mid-apply straddle. Parking the DB + secrets in the rarely-touched
# substrate keeps identity a clean ansible→TF layer.
#
# Folded here from the v0.1.0 platform/identity/bootstrap (now
# platform/infra/authentik-bootstrap). In v0.1.0 the consumer stack called it
# as module.identity_bootstrap alongside module.base; v1.0 nests it inside the
# infra composition so the four-layer split is clean.
#
# Carve note (1→4 migration / no-op dry-run): prod's
#   module.stack.module.identity_bootstrap.*
# maps to
#   module.infra.module.authentik_bootstrap[0].*
# — a state-mv prefix swap + the [0] from the count gate below.
#
# Variables + outputs are colocated here (rather than in the shared
# variables.tf/outputs.tf) because they exist only to wire this one folded
# concern; they travel together if the fold ever changes.

module "authentik_bootstrap" {
  source = "../authentik-bootstrap"
  # Authentik needs its DB; gate on the shared postgres instance existing.
  count = var.postgres_enabled ? 1 : 0

  org_slug    = var.org_slug
  environment = var.environment
  infra_email = var.infra_email

  postgres_instance_id = module.postgres[0].instance_id
  postgres_endpoint    = module.postgres[0].endpoint
  postgres_engine      = var.postgres_engine

  tags = var.tags

  admin_username     = var.authentik_admin_username
  media_s3_secret_id = var.authentik_media_s3_secret_id
  smtp_secret_id     = var.authentik_smtp_secret_id
  authentik_version  = var.authentik_version
}

# ── Inputs ──────────────────────────────────────────────────────────────────

variable "infra_email" {
  description = "Operations contact email. Used as the Authentik bootstrap admin user's email; also surfaced to ansible (traefik ACME registration)."
  type        = string
}

variable "authentik_admin_username" {
  description = "Authentik bootstrap admin username (informational in the secret; Authentik itself uses AUTHENTIK_BOOTSTRAP_* on first boot)."
  type        = string
  default     = "akadmin"
}

variable "authentik_media_s3_secret_id" {
  description = "Scaleway secret ID for Authentik media-storage S3 credentials. Empty = filesystem media. Provisioned out-of-band; this just plumbs the ID to the authentik-server ansible role."
  type        = string
  default     = ""
}

variable "authentik_smtp_secret_id" {
  description = "Scaleway secret ID for Authentik's own SMTP credentials. Empty = email steps no-op. Provisioned out-of-band."
  type        = string
  default     = ""
}

# Backported from master's authentik-version-knob (arrived via rebase): the
# consumer-facing knob to pin the Authentik image tag. Threaded through to the
# bootstrap module → identity_bootstrap output → authentik-server ansible role.
variable "authentik_version" {
  description = "Authentik image tag to pin (e.g. \"2025.12.1\"). Empty (default) defers to the authentik-server role's validated default. Authentik has breaking inter-release DB migrations — set deliberately."
  type        = string
  default     = ""
}

# ── Outputs ─────────────────────────────────────────────────────────────────
# Consumed by the consumer's infra root: the identity_bootstrap map feeds
# ansible bootstrap.yml's authentik-server role; admin_secret_id is where the
# deploy path fetches api_token for TF_VAR_authentik_admin_token. Downstream
# layers (identity/operations/application) rediscover these by name via
# data.scaleway_secret on the ${org}-${env}-authentik-* secrets, not via these
# outputs (no remote_state — see V1.0-PLAN contract surface).

output "identity_bootstrap" {
  description = "Map of Scaleway secret IDs the authentik-server ansible role consumes (postgres/admin/server/media_s3/smtp). null when postgres is disabled."
  value       = var.postgres_enabled ? module.authentik_bootstrap[0].identity_bootstrap : null
}

output "authentik_admin_secret_id" {
  description = "Scaleway secret ID for the Authentik bootstrap admin JSON {username,email,password,api_token}. Fetch api_token → TF_VAR_authentik_admin_token for the identity/operations/application authentik providers."
  value       = var.postgres_enabled ? module.authentik_bootstrap[0].admin_secret_id : null
}

output "authentik_server_secret_id" {
  description = "Scaleway secret ID for the Authentik server-side secret_key (cookie signing)."
  value       = var.postgres_enabled ? module.authentik_bootstrap[0].server_secret_id : null
}

output "authentik_database_secret_id" {
  description = "Scaleway secret ID for the Authentik PostgreSQL database credentials."
  value       = var.postgres_enabled ? module.authentik_bootstrap[0].database_secret_id : null
}
