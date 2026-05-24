module "identity" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/identity/terraform?ref=v2.5.0"

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
  extra_forward_auth_provider_ids = compact([
    module.bentopdf.authentik_provider_id,
    module.backrest_mgmt.authentik_provider_id,
  ])
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
