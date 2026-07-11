# Identity layer root. Configures the Authentik server (tier groups + nesting,
# flows, branding, sources, notifications) via the Authentik API.
#
# Apply rhythm: the deploy scripts run the identity ANSIBLE play first (which
# boots the Authentik server container using the secrets infra minted), then
# apply this layer (which configures Authentik through the provider using the
# bootstrap admin token). See scripts/identity.sh.

locals {
  env_name = basename(dirname(abspath(path.root)))
  common   = yamldecode(file("${path.root}/../../common.yml"))
  env      = yamldecode(file("${path.root}/../env.yml"))
  identity = yamldecode(file("${path.root}/../identity.yml"))
  infra    = yamldecode(file("${path.root}/../infra.yml"))
}

module "identity" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/identity/terraform?ref=v0.2.5-beta1"
  providers = {
    scaleway  = scaleway
    authentik = authentik
  }

  identity_domain = local.env.identity_domain
  base_domain     = local.env.base_domain
  org_name        = local.common.org_name
  org_slug        = local.common.org_slug
  infra_email     = local.env.infra_email
  icon_base_url   = local.common.icon_base_url
  api_url         = "https://${local.env.identity_domain}"

  # Tier DAG (required) + extra non-tier groups.
  tier_slots   = local.identity.tier_slots
  extra_groups = try(local.identity.extra_groups, {})

  smtp_secret_name = try(local.infra.tem_smtp_config_secret_name, "smtp-config")

  # Named-group pointers (module defaults: admin/member/delegate).
  admin_group_name    = try(local.identity.admin_group_name, "admin")
  member_group_name   = try(local.identity.member_group_name, "member")
  delegate_group_name = try(local.identity.delegate_group_name, "delegate")
  delegate_role_name  = try(local.identity.delegate_role_name, "delegate")
  admin_user_pks      = try(local.identity.admin_user_pks, null)

  admin_email = try(local.identity.admin_email, "")
  from_name   = try(local.identity.from_name, "")

  branding_logo                    = try(local.identity.branding_logo, "logo.png")
  branding_favicon                 = try(local.identity.branding_favicon, "favicon.png")
  branding_default_flow_background = try(local.identity.branding_default_flow_background, "background.jpg")

  enable_google_social_login = try(local.identity.enable_google_social_login, false)
  enable_apple_social_login  = try(local.identity.enable_apple_social_login, false)

  notification_webhook_url                  = try(local.identity.notification_webhook_url, "")
  notification_test_mode                    = try(local.identity.notification_test_mode, false)
  notification_support_contact_instructions = try(local.identity.notification_support_contact_instructions, "Contact your administrator if you have questions.")
  notification_welcome_message              = try(local.identity.notification_welcome_message, "Welcome!")

  member_id_label = try(local.identity.member_id_label, "Member ID")
}
