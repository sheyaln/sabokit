# One module call per app. All gated by var.apps.<name>.enabled (default false).
# Uncomment / enable in terraform.tfvars to turn an app on.

module "outline" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/outline/terraform?ref=v2.5.0"

  enabled  = try(var.apps.outline.enabled, false)
  hostname = try(var.apps.outline.hostname, "")
  base     = local.base

  # Optional overrides
  access_level            = try(var.apps.outline.access_level, "member")
  extra_authorized_groups = try(var.apps.outline.extra_authorized_groups, {})
  smtp_from_email         = try(var.apps.outline.smtp_from_email, "")
  monitoring_enabled      = try(var.apps.outline.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.outline.deployment_host_key, "apps")
}

module "steward" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/steward/terraform?ref=v2.5.0"

  enabled  = try(var.apps.steward.enabled, false)
  hostname = try(var.apps.steward.hostname, "")
  base     = local.base

  # Optional overrides
  access_level            = try(var.apps.steward.access_level, "admin")
  extra_authorized_groups = try(var.apps.steward.extra_authorized_groups, {})
  admin_group_name        = try(var.apps.steward.admin_group_name, "union-delegate")
  invite_flow_slug        = try(var.apps.steward.invite_flow_slug, "")
  image_repository        = try(var.apps.steward.image_repository, "ghcr.io/sheyaln/sabokit-steward")
  image_tag               = try(var.apps.steward.image_tag, "latest")
  monitoring_enabled      = try(var.apps.steward.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.steward.deployment_host_key, "apps")
}

module "vikunja" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/vikunja/terraform?ref=v2.5.0"

  enabled  = try(var.apps.vikunja.enabled, false)
  hostname = try(var.apps.vikunja.hostname, "")
  base     = local.base

  # Optional overrides
  access_level            = try(var.apps.vikunja.access_level, "member")
  extra_authorized_groups = try(var.apps.vikunja.extra_authorized_groups, {})
  timezone                = try(var.apps.vikunja.timezone, "UTC")
  enable_registration     = try(var.apps.vikunja.enable_registration, false)
  enable_local_auth       = try(var.apps.vikunja.enable_local_auth, false)
  smtp_from_email         = try(var.apps.vikunja.smtp_from_email, "")
  oidc_groups_scope_name  = try(var.apps.vikunja.oidc_groups_scope_name, "vikunja_scope")
  monitoring_enabled      = try(var.apps.vikunja.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.vikunja.deployment_host_key, "apps")
}

# Forward-auth app (no OIDC). Its provider_id MUST also be added to the
# identity module's extra_forward_auth_provider_ids list — see identity.tf.
module "bentopdf" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/bentopdf/terraform?ref=v2.5.0"

  enabled  = try(var.apps.bentopdf.enabled, false)
  hostname = try(var.apps.bentopdf.hostname, "")
  base     = local.base

  # Optional overrides
  access_level            = try(var.apps.bentopdf.access_level, "member")
  extra_authorized_groups = try(var.apps.bentopdf.extra_authorized_groups, {})
  image                   = try(var.apps.bentopdf.image, "ghcr.io/digital-blueprint/bento-pdf:latest")
  monitoring_enabled      = try(var.apps.bentopdf.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.bentopdf.deployment_host_key, "apps")
}

# Public — no auth integration. Privacy policies must be reachable without login.
module "privacy_policy" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/privacy-policy/terraform?ref=v2.5.0"

  enabled  = try(var.apps.privacy_policy.enabled, false)
  hostname = try(var.apps.privacy_policy.hostname, "")
  base     = local.base

  page_title          = try(var.apps.privacy_policy.page_title, "Privacy Policy")
  monitoring_enabled  = try(var.apps.privacy_policy.monitoring_enabled, true)
  deployment_host_key = try(var.apps.privacy_policy.deployment_host_key, "apps")
}

module "notifuse" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/notifuse/terraform?ref=v2.5.0"

  enabled          = try(var.apps.notifuse.enabled, false)
  hostname         = try(var.apps.notifuse.hostname, "")
  root_admin_email = try(var.apps.notifuse.root_admin_email, "")
  base             = local.base

  access_level            = try(var.apps.notifuse.access_level, "admin")
  extra_authorized_groups = try(var.apps.notifuse.extra_authorized_groups, {})
  smtp_from_email         = try(var.apps.notifuse.smtp_from_email, "")
  oidc_auto_provision     = try(var.apps.notifuse.oidc_auto_provision, true)
  oidc_allow_magic_code   = try(var.apps.notifuse.oidc_allow_magic_code, true)
  monitoring_enabled      = try(var.apps.notifuse.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.notifuse.deployment_host_key, "apps")
}

# Nextcloud + OnlyOffice + Talk HPB ship as one stack — three hostnames
# (the main UI, the OnlyOffice editor, and the Talk signaling/TURN endpoint).
# Talk HPB needs UDP/TCP 3478 + UDP 49152-49252 open in the security group on
# top of the host firewall — extend default_security_group_extra_inbound_rules
# in module.base accordingly.
module "nextcloud" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/nextcloud/terraform?ref=v2.5.0"

  enabled             = try(var.apps.nextcloud.enabled, false)
  hostname            = try(var.apps.nextcloud.hostname, "")
  onlyoffice_hostname = try(var.apps.nextcloud.onlyoffice_hostname, "")
  talk_hostname       = try(var.apps.nextcloud.talk_hostname, "")
  base                = local.base

  access_level            = try(var.apps.nextcloud.access_level, "member")
  extra_authorized_groups = try(var.apps.nextcloud.extra_authorized_groups, {})
  image_tag               = try(var.apps.nextcloud.image_tag, "32-apache")
  admin_username          = try(var.apps.nextcloud.admin_username, "ncadmin")
  default_phone_region    = try(var.apps.nextcloud.default_phone_region, "US")
  max_upload_size_bytes   = try(var.apps.nextcloud.max_upload_size_bytes, 2147483648)
  smtp_from_email         = try(var.apps.nextcloud.smtp_from_email, "")
  monitoring_enabled      = try(var.apps.nextcloud.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.nextcloud.deployment_host_key, "apps")
}

module "decidim" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/decidim/terraform?ref=v2.5.0"

  enabled            = try(var.apps.decidim.enabled, false)
  hostname           = try(var.apps.decidim.hostname, "")
  organization_name  = try(var.apps.decidim.organization_name, "")
  system_admin_email = try(var.apps.decidim.system_admin_email, "")
  base               = local.base

  access_level                  = try(var.apps.decidim.access_level, "member")
  extra_authorized_groups       = try(var.apps.decidim.extra_authorized_groups, {})
  image_tag                     = try(var.apps.decidim.image_tag, "0.28")
  default_locale                = try(var.apps.decidim.default_locale, "en")
  available_locales             = try(var.apps.decidim.available_locales, ["en"])
  organization_reference_prefix = try(var.apps.decidim.organization_reference_prefix, "")
  organization_admin_email      = try(var.apps.decidim.organization_admin_email, "")
  smtp_from_email               = try(var.apps.decidim.smtp_from_email, "")
  sidekiq_concurrency           = try(var.apps.decidim.sidekiq_concurrency, 5)
  monitoring_enabled            = try(var.apps.decidim.monitoring_enabled, true)
  deployment_host_key           = try(var.apps.decidim.deployment_host_key, "apps")
}

# OIDC via an adapter (NOT forward-auth — don't add jitsi.authentik_provider_id
# to extra_forward_auth_provider_ids below). The adapter brokers between
# Authentik's OIDC dance and Jitsi's JWT room-token model.
module "jitsi" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/jitsi/terraform?ref=v2.5.0"

  enabled  = try(var.apps.jitsi.enabled, false)
  hostname = try(var.apps.jitsi.hostname, "")
  base     = local.base

  access_level               = try(var.apps.jitsi.access_level, "member")
  extra_authorized_groups    = try(var.apps.jitsi.extra_authorized_groups, {})
  image_tag                  = try(var.apps.jitsi.image_tag, "stable-9823")
  timezone                   = try(var.apps.jitsi.timezone, "UTC")
  jvb_udp_port               = try(var.apps.jitsi.jvb_udp_port, 10000)
  jvb_stun_servers           = try(var.apps.jitsi.jvb_stun_servers, "meet-jit-si-turnrelay.jitsi.net:443")
  enable_lobby               = try(var.apps.jitsi.enable_lobby, true)
  enable_breakout_rooms      = try(var.apps.jitsi.enable_breakout_rooms, true)
  enable_prejoin_page        = try(var.apps.jitsi.enable_prejoin_page, true)
  oidc_adapter_image_repo    = try(var.apps.jitsi.oidc_adapter_image_repo, "https://github.com/sabokit/jitsi-oidc-adapter.git")
  oidc_adapter_image_version = try(var.apps.jitsi.oidc_adapter_image_version, "main")
  oidc_log_level             = try(var.apps.jitsi.oidc_log_level, "INFO")
  monitoring_enabled         = try(var.apps.jitsi.monitoring_enabled, true)
  deployment_host_key        = try(var.apps.jitsi.deployment_host_key, "apps")
}

module "espocrm" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/espocrm/terraform?ref=v2.5.0"

  enabled  = try(var.apps.espocrm.enabled, false)
  hostname = try(var.apps.espocrm.hostname, "")
  base     = local.base

  access_level                   = try(var.apps.espocrm.access_level, "member")
  extra_authorized_groups        = try(var.apps.espocrm.extra_authorized_groups, {})
  image_tag                      = try(var.apps.espocrm.image_tag, "8.5")
  timezone                       = try(var.apps.espocrm.timezone, "UTC")
  admin_username                 = try(var.apps.espocrm.admin_username, "admin")
  b2c_mode                       = try(var.apps.espocrm.b2c_mode, true)
  oidc_username_claim            = try(var.apps.espocrm.oidc_username_claim, "preferred_username")
  oidc_group_claim               = try(var.apps.espocrm.oidc_group_claim, "groups")
  oidc_team_id_prefix            = try(var.apps.espocrm.oidc_team_id_prefix, "sso-")
  oidc_group_role_mapping        = try(var.apps.espocrm.oidc_group_role_mapping, {})
  enable_member_entity_bootstrap = try(var.apps.espocrm.enable_member_entity_bootstrap, false)
  member_entity_webhooks         = try(var.apps.espocrm.member_entity_webhooks, [])
  monitoring_enabled             = try(var.apps.espocrm.monitoring_enabled, true)
  deployment_host_key            = try(var.apps.espocrm.deployment_host_key, "apps")
}

module "n8n" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/n8n/terraform?ref=v2.5.0"

  enabled  = try(var.apps.n8n.enabled, false)
  hostname = try(var.apps.n8n.hostname, "")
  base     = local.base

  access_level            = try(var.apps.n8n.access_level, "member")
  extra_authorized_groups = try(var.apps.n8n.extra_authorized_groups, {})
  image_tag               = try(var.apps.n8n.image_tag, "latest")
  n8n_admin_group_name    = try(var.apps.n8n.n8n_admin_group_name, "admin")
  timezone                = try(var.apps.n8n.timezone, "UTC")
  public_api_disabled     = try(var.apps.n8n.public_api_disabled, true)
  monitoring_enabled      = try(var.apps.n8n.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.n8n.deployment_host_key, "apps")
}

# App bundles export their backup contribution as `backup_plan` (null when
# disabled or backup_enabled=false). Aggregate and pass to every backrest
# instance — same plug-and-play pattern as required_inbound_rules for SG.
# Each backrest only backs up paths that exist on its own host; restic skips
# missing ones, so passing the full union is safe.
locals {
  aggregated_backup_plans = [for plan in [
    module.outline.backup_plan,
    module.steward.backup_plan,
    module.vikunja.backup_plan,
    module.bentopdf.backup_plan,
    module.privacy_policy.backup_plan,
    module.notifuse.backup_plan,
    module.nextcloud.backup_plan,
    module.decidim.backup_plan,
    module.jitsi.backup_plan,
    module.espocrm.backup_plan,
    module.n8n.backup_plan,
  ] : plan if plan != null]
}

# Backrest is multi-instance: each backed-up host gets its own module block,
# its own bucket, its own restic repo. Forward-auth — its provider_id MUST
# be added to identity's extra_forward_auth_provider_ids list (see identity.tf).
# Example: a single "mgmt" instance. Add more module blocks for each host.
module "backrest_mgmt" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/backrest/terraform?ref=v2.5.0"

  enabled       = try(var.apps.backrest_mgmt.enabled, false)
  hostname      = try(var.apps.backrest_mgmt.hostname, "")
  instance_name = try(var.apps.backrest_mgmt.instance_name, "mgmt")
  # Auto-backed-up from every enabled app's backup_plan output, plus any
  # consumer-supplied extras.
  backup_plans = concat(
    local.aggregated_backup_plans,
    try(var.apps.backrest_mgmt.backup_plans, []),
  )
  base = local.base

  access_level                          = try(var.apps.backrest_mgmt.access_level, "admin")
  extra_authorized_groups               = try(var.apps.backrest_mgmt.extra_authorized_groups, {})
  image_tag                             = try(var.apps.backrest_mgmt.image_tag, "latest")
  backup_sources                        = try(var.apps.backrest_mgmt.backup_sources, {})
  restic_prune_max_frequency_days       = try(var.apps.backrest_mgmt.restic_prune_max_frequency_days, 7)
  restic_check_max_frequency_days       = try(var.apps.backrest_mgmt.restic_check_max_frequency_days, 30)
  restic_check_read_data_subset_percent = try(var.apps.backrest_mgmt.restic_check_read_data_subset_percent, 5)
  monitoring_enabled                    = try(var.apps.backrest_mgmt.monitoring_enabled, true)
  deployment_host_key                   = try(var.apps.backrest_mgmt.deployment_host_key, "apps")
}

# ── Platform host-services (one container per host) ─────────────────────────
# Watchtower auto-updates opted-in app containers; Autoheal restarts unhealthy
# ones. Multi-instance like backrest — one block per host you want them on.
# Each app bundle's per-app `auto_update_enabled` / `autoheal_enabled` knobs
# decide which containers are labelled for these to act on.

module "watchtower_apps" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/watchtower/terraform?ref=v2.5.0"

  enabled = try(var.apps.watchtower_apps.enabled, false)
  base    = local.base

  deployment_host_key         = try(var.apps.watchtower_apps.deployment_host_key, "apps")
  image_tag                   = try(var.apps.watchtower_apps.image_tag, "latest")
  schedule                    = try(var.apps.watchtower_apps.schedule, "0 0 4 * * *")
  notifications_slack_webhook = try(var.apps.watchtower_apps.notifications_slack_webhook, "")
}

module "autoheal_apps" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/autoheal/terraform?ref=v2.5.0"

  enabled = try(var.apps.autoheal_apps.enabled, false)
  base    = local.base

  deployment_host_key  = try(var.apps.autoheal_apps.deployment_host_key, "apps")
  image_tag            = try(var.apps.autoheal_apps.image_tag, "latest")
  interval_seconds     = try(var.apps.autoheal_apps.interval_seconds, 5)
  start_period_seconds = try(var.apps.autoheal_apps.start_period_seconds, 60)
}
