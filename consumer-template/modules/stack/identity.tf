module "identity" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/identity/terraform?ref=v3.5.2"

  gateway_domain = module.base.domains.gateway_domain
  base_domain    = module.base.domains.base_domain

  org_name    = var.org_name
  org_slug    = var.org_slug
  infra_email = var.infra_email

  # SMTP is off by default (empty secret name). Set smtp_secret_name in your
  # terraform.tfvars once you've created a {smtp_host, smtp_port, smtp_username,
  # smtp_password} secret in Scaleway Secret Manager.
  smtp_secret_name = var.smtp_secret_name

  # Forward-auth providers from any enabled apps/* bundles register here.
  # compact() drops nulls from disabled apps.
  #
  # Jitsi is NOT included even though it exports authentik_provider_id —
  # it uses its own OIDC adapter, not the embedded outpost. See its README.
  extra_forward_auth_provider_ids = compact(concat(
    [
      module.bentopdf.authentik_provider_id,
    ],
    [for inst in module.backrest : inst.authentik_provider_id],
  ))

  # Tier DAG. Required input — the consumer declares their authority
  # hierarchy as a list of slots, each holding a map of peer_name → group_name.
  # See terraform.tfvars.example for the shape and platform/identity/terraform/
  # README.md for the cascade-up semantics.
  tier_slots = var.identity.tier_slots

  # Named-group pointers. Each must match a group_name that exists in
  # tier_slots above. Defaults track the platform-module defaults; override
  # per consumer when the DAG names its groups differently (e.g. point
  # delegate_group_name at a "Steward" or "Coordinator" group).
  admin_group_name    = try(var.identity.admin_group_name, "admin")
  member_group_name   = try(var.identity.member_group_name, "member")
  delegate_group_name = try(var.identity.delegate_group_name, "delegate")
  delegate_role_name  = try(var.identity.delegate_role_name, "delegate")

  # Extra Authentik groups beyond the tier_slots DAG (service-account scopes,
  # org-specific roles, etc.). Each entry produces an `authentik_group`
  # surfaced via `var.base.authentik.groups[<name>]`. Apps with service
  # accounts (n8n, steward) consume by name via `service_account_extra_groups`.
  extra_groups = try(var.identity.extra_groups, {})

  # Where app bundles fetch icons by filename. Empty = use the identity
  # module's default (sabokit-assets pinned tag). Override to point at your
  # own CDN / internal mirror to retheme every app icon at once.
  icon_base_url = try(var.identity.icon_base_url, "")
}

# The merged "base" object app bundles consume. Apps reference
# var.base.{scaleway, identity, compute, domains}.
locals {
  base = {
    scaleway = module.base.scaleway
    compute  = module.base.compute
    domains  = module.base.domains

    # Authentik is exposed under base.authentik for app convenience even
    # though it's produced by module.identity — apps don't need to know
    # whether identity is platform-provided or external.
    authentik = module.identity.authentik
  }
}
