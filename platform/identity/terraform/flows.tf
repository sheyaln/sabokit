module "flows" {
  source = "./flows"

  # Social-login UUIDs are passed even when the source is disabled — pass an
  # empty string in that case and let the flows submodule branch on it.
  google_social_login_uuid = var.enable_google_social_login ? authentik_source_oauth.google[0].uuid : ""
  apple_social_login_uuid  = var.enable_apple_social_login ? authentik_source_oauth.apple[0].uuid : ""

  # Enrolling users land in the standard-member group (lowest tier in the cascade).
  member_group_id = module.tier_cascade.groups[var.member_group_name]

  # SMTP for email-bearing flows (password reset, MFA reset, invitations).
  # When smtp_enabled is false the stages are still created but flip to
  # use_global_settings = true with null host/port — the flow plans cleanly
  # and the consumer can add SMTP later without recreating it.
  smtp_enabled  = local.smtp_enabled
  smtp_host     = local.smtp_config.smtp_host
  smtp_port     = local.smtp_config.smtp_port
  smtp_username = local.smtp_config.smtp_username
  smtp_password = local.smtp_config.smtp_password

  # Org identity used in flow titles and email bodies.
  domain            = var.base_domain
  organisation_name = var.org_name

  # Branding.
  flow_background = var.branding_default_flow_background

  # User-lifecycle webhook (empty disables the webhook step inside the flow).
  notification_webhook_url = var.notification_webhook_url

  # Admin-tier group names used by the unenrollment guard policy.
  admin_group_name    = var.admin_group_name
  delegate_group_name = var.delegate_group_name
}
