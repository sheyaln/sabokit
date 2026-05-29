# The discovery half of the data-source contract. Every block here finds an
# object infra or identity already provisioned, keyed by the ${org}-${env}
# naming/tagging convention those layers apply. No remote_state: apply order
# is enforced for free — a downstream plan fails to refresh if an upstream
# resource is absent, which is exactly the "infra before me" guarantee.

locals {
  name_suffix = "${var.org_slug}-${var.environment}"

  # Domain fallbacks mirror infra's locals.tf so base.domains matches what
  # infra emitted, byte-for-byte, regardless of whether the consumer set the
  # optional domains explicitly.
  mgmt_domain     = var.mgmt_domain != null ? var.mgmt_domain : var.base_domain
  identity_domain = (var.identity_domain != null && var.identity_domain != "") ? var.identity_domain : "auth.${var.base_domain}"

  # Roles to resolve a per-role SG for. Infra names role SGs ${org}-${env}-<role>.
  roles = distinct([for _, h in var.compute_hosts : h.role])

  # Flat set of group names to discover, deduped.
  group_names = distinct(var.group_names)

  # group_name → group_id, the lookup table bundles resolve authorized_groups
  # against (and the whole of base.authentik.groups).
  discovered_groups = { for n in local.group_names : n => data.authentik_group.this[n].id }
}

# ── Scaleway substrate (produced by infra) ───────────────────────────────────

data "scaleway_vpc_private_network" "this" {
  name = "${local.name_suffix}-network"
}

data "scaleway_rdb_instance" "this" {
  count = var.postgres_enabled ? 1 : 0
  name  = "${local.name_suffix}-postgres"
}

# Admin-credentials bag the postgres module writes. Surfaced for shape parity
# (apps provision their own DBs via the Scaleway API, not this secret), so the
# lookup is best-effort under the same postgres gate.
data "scaleway_secret" "postgres_admin" {
  count = var.postgres_enabled ? 1 : 0
  name  = "${local.name_suffix}-postgres-admin-credentials"
}

# One SG per distinct host role; infra owns these as a static per-role superset.
data "scaleway_instance_security_group" "role" {
  for_each = toset(local.roles)
  name     = "${local.name_suffix}-${each.key}"
}

# Per-host lookup (singular, not the plural servers list) so we get private_ips
# reliably and can match the consumer's host_key → infra instance name.
data "scaleway_instance_server" "host" {
  for_each = var.compute_hosts
  name     = "${local.name_suffix}-${each.key}"
  zone     = var.scaleway_zone
}

# TEM outbound SMTP bag, read by name (the well-known smtp-config). Consumed by
# the prometheus tem-exporter; null when the consumer runs without TEM.
data "scaleway_secret" "smtp_config" {
  count = var.smtp_secret_name != "" ? 1 : 0
  name  = var.smtp_secret_name
}

# ── Authentik objects (produced by identity) ─────────────────────────────────

data "authentik_group" "this" {
  for_each = toset(local.group_names)
  name     = each.value
}

# The custom local authentication flow identity creates. Built-ins below are
# discovered by their stock slugs.
data "authentik_flow" "authentication" {
  slug = "authentication-local-username-and-passkey"
}

data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}
