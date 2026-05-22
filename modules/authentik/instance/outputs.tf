# ── App identities ──────────────────────────────────────────────────────────

output "n8n_provider_id" {
  description = "ID of the n8n Proxy Provider (bound to Embedded Outpost)"
  value       = module.n8n.provider_id
}

output "embedded_outpost_id" {
  description = "ID of the Authentik Embedded Outpost"
  value       = authentik_outpost.embedded.id
}

# ── Member groups ───────────────────────────────────────────────────────────
# Exposed so root-level org-specific app/bookmark definitions can attach to
# the same RBAC groups the module-managed apps use.

output "member_groups" {
  description = "Map of the 4 standard member groups (admin, union_delegate, union_member, union_treasurer) for use in root-level bookmark/app modules."
  value = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }
}

output "group_admin_id" {
  description = "ID of the admin group"
  value       = authentik_group.admin.id
}

output "group_union_delegate_id" {
  description = "ID of the union_delegate group"
  value       = authentik_group.union_delegate.id
}

output "group_union_member_id" {
  description = "ID of the union_member group"
  value       = authentik_group.union_member.id
}

output "group_union_treasurer_id" {
  description = "ID of the union_treasurer group"
  value       = authentik_group.union_treasurer.id
}

# ── Flows ───────────────────────────────────────────────────────────────────
# Exposed for any root-level app that wants to use the same flows the catalog
# uses (rather than registering its own).

output "flows" {
  description = "Flow UUIDs from the flows submodule, surfaced for root-level apps"
  value = {
    authentication_flow_login                          = module.flows.authentication_flow_login
    default_provider_authorization_implicit_consent_id = module.flows.default_provider_authorization_implicit_consent_id
    default_provider_invalidation_flow_id              = module.flows.default_provider_invalidation_flow_id
  }
}
