# One module call per app. All gated by var.apps.<name>.enabled (default false).
# Uncomment / enable in terraform.tfvars to turn an app on.

module "outline" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/outline/terraform?ref=v3.1.9"

  enabled  = try(var.apps.outline.enabled, false)
  hostname = try(var.apps.outline.hostname, "")
  base     = local.base

  # Optional overrides
  access_level            = try(var.apps.outline.access_level, "member")
  extra_authorized_groups = try(var.apps.outline.extra_authorized_groups, {})
  tier_cascade_enabled    = try(var.apps.outline.tier_cascade_enabled, true)
  tier_access_level       = try(var.apps.outline.tier_access_level, "admin")
  smtp_from_email         = try(var.apps.outline.smtp_from_email, "")
  application_name        = try(var.apps.outline.application_name, "Wiki (Outline)")
  application_slug        = try(var.apps.outline.application_slug, "")
  category_group          = try(var.apps.outline.category_group, "Collaboration")
  icon_url                = try(var.apps.outline.icon_url, null)
  icon_filename           = try(var.apps.outline.icon_filename, "outline-icon.png")
  monitoring_enabled      = try(var.apps.outline.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.outline.deployment_host_key, "apps")
  bucket_name_override    = try(var.apps.outline.bucket_name_override, "")
  dns_zone_override       = try(var.apps.outline.dns_zone_override, "")

  credentials_preserve = try(var.apps.outline.credentials_preserve, false)
}

module "steward" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/steward/terraform?ref=v3.1.9"

  enabled  = try(var.apps.steward.enabled, false)
  hostname = try(var.apps.steward.hostname, "")
  base     = local.base

  # Optional overrides
  access_level                 = try(var.apps.steward.access_level, "admin")
  extra_authorized_groups      = try(var.apps.steward.extra_authorized_groups, {})
  tier_cascade_enabled         = try(var.apps.steward.tier_cascade_enabled, true)
  tier_access_level            = try(var.apps.steward.tier_access_level, "admin")
  admin_group_name             = try(var.apps.steward.admin_group_name, "union-delegate")
  invite_flow_slug             = try(var.apps.steward.invite_flow_slug, "")
  image_repository             = try(var.apps.steward.image_repository, "ghcr.io/sheyaln/sabokit-steward")
  image_tag                    = try(var.apps.steward.image_tag, "latest")
  application_name             = try(var.apps.steward.application_name, "Steward")
  application_slug             = try(var.apps.steward.application_slug, "")
  category_group               = try(var.apps.steward.category_group, "Member Operations")
  icon_url                     = try(var.apps.steward.icon_url, null)
  icon_filename                = try(var.apps.steward.icon_filename, "steward-icon.png")
  service_account_extra_groups = try(var.apps.steward.service_account_extra_groups, [])
  monitoring_enabled           = try(var.apps.steward.monitoring_enabled, true)
  deployment_host_key          = try(var.apps.steward.deployment_host_key, "apps")
  dns_zone_override            = try(var.apps.steward.dns_zone_override, "")

  credentials_preserve = try(var.apps.steward.credentials_preserve, false)
}

module "vikunja" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/vikunja/terraform?ref=v3.1.9"

  enabled  = try(var.apps.vikunja.enabled, false)
  hostname = try(var.apps.vikunja.hostname, "")
  base     = local.base

  # Optional overrides
  access_level            = try(var.apps.vikunja.access_level, "member")
  extra_authorized_groups = try(var.apps.vikunja.extra_authorized_groups, {})
  tier_cascade_enabled    = try(var.apps.vikunja.tier_cascade_enabled, true)
  tier_access_level       = try(var.apps.vikunja.tier_access_level, "admin")
  timezone                = try(var.apps.vikunja.timezone, "UTC")
  enable_registration     = try(var.apps.vikunja.enable_registration, false)
  enable_local_auth       = try(var.apps.vikunja.enable_local_auth, false)
  smtp_from_email         = try(var.apps.vikunja.smtp_from_email, "")
  oidc_groups_scope_name  = try(var.apps.vikunja.oidc_groups_scope_name, "vikunja_scope")
  application_name        = try(var.apps.vikunja.application_name, "Tasks (Vikunja)")
  application_slug        = try(var.apps.vikunja.application_slug, "")
  category_group          = try(var.apps.vikunja.category_group, "Collaboration")
  icon_url                = try(var.apps.vikunja.icon_url, null)
  icon_filename           = try(var.apps.vikunja.icon_filename, "vikunja-icon.png")
  monitoring_enabled      = try(var.apps.vikunja.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.vikunja.deployment_host_key, "apps")
  dns_zone_override       = try(var.apps.vikunja.dns_zone_override, "")

  credentials_preserve = try(var.apps.vikunja.credentials_preserve, false)
}

# Forward-auth app (no OIDC). Its provider_id MUST also be added to the
# identity module's extra_forward_auth_provider_ids list — see identity.tf.
module "bentopdf" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/bentopdf/terraform?ref=v3.1.9"

  enabled  = try(var.apps.bentopdf.enabled, false)
  hostname = try(var.apps.bentopdf.hostname, "")
  base     = local.base

  # Optional overrides
  access_level            = try(var.apps.bentopdf.access_level, "member")
  extra_authorized_groups = try(var.apps.bentopdf.extra_authorized_groups, {})
  tier_cascade_enabled    = try(var.apps.bentopdf.tier_cascade_enabled, true)
  tier_access_level       = try(var.apps.bentopdf.tier_access_level, "admin")
  image                   = try(var.apps.bentopdf.image, "ghcr.io/digital-blueprint/bento-pdf:latest")
  application_name        = try(var.apps.bentopdf.application_name, "PDF Tools (BentoPDF)")
  application_slug        = try(var.apps.bentopdf.application_slug, "")
  category_group          = try(var.apps.bentopdf.category_group, "Collaboration")
  icon_url                = try(var.apps.bentopdf.icon_url, null)
  icon_filename           = try(var.apps.bentopdf.icon_filename, "bentopdf-icon.png")
  monitoring_enabled      = try(var.apps.bentopdf.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.bentopdf.deployment_host_key, "apps")
  dns_zone_override       = try(var.apps.bentopdf.dns_zone_override, "")
}

# Public — no auth integration. Privacy policies must be reachable without login.
module "privacy_policy" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/privacy-policy/terraform?ref=v3.1.9"

  enabled  = try(var.apps.privacy_policy.enabled, false)
  hostname = try(var.apps.privacy_policy.hostname, "")
  base     = local.base

  page_title          = try(var.apps.privacy_policy.page_title, "Privacy Policy")
  monitoring_enabled  = try(var.apps.privacy_policy.monitoring_enabled, true)
  deployment_host_key = try(var.apps.privacy_policy.deployment_host_key, "apps")
  dns_zone_override   = try(var.apps.privacy_policy.dns_zone_override, "")
}

module "notifuse" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/notifuse/terraform?ref=v3.1.9"

  enabled          = try(var.apps.notifuse.enabled, false)
  hostname         = try(var.apps.notifuse.hostname, "")
  root_admin_email = try(var.apps.notifuse.root_admin_email, "")
  base             = local.base

  access_level            = try(var.apps.notifuse.access_level, "admin")
  extra_authorized_groups = try(var.apps.notifuse.extra_authorized_groups, {})
  tier_cascade_enabled    = try(var.apps.notifuse.tier_cascade_enabled, true)
  tier_access_level       = try(var.apps.notifuse.tier_access_level, "admin")
  smtp_from_email         = try(var.apps.notifuse.smtp_from_email, "")
  oidc_auto_provision     = try(var.apps.notifuse.oidc_auto_provision, true)
  oidc_allow_magic_code   = try(var.apps.notifuse.oidc_allow_magic_code, true)
  application_name        = try(var.apps.notifuse.application_name, "Notifuse")
  application_slug        = try(var.apps.notifuse.application_slug, "")
  category_group          = try(var.apps.notifuse.category_group, "Member Engagement")
  icon_url                = try(var.apps.notifuse.icon_url, null)
  icon_filename           = try(var.apps.notifuse.icon_filename, "")
  monitoring_enabled      = try(var.apps.notifuse.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.notifuse.deployment_host_key, "apps")
  bucket_name_override    = try(var.apps.notifuse.bucket_name_override, "")
  dns_zone_override       = try(var.apps.notifuse.dns_zone_override, "")

  credentials_preserve = try(var.apps.notifuse.credentials_preserve, false)
}

# Broadsheet — sabokit-broadsheet fork of notifuse. Replaces notifuse going
# forward; notifuse stays through one more v2.x cycle for migration headroom.
module "broadsheet" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/broadsheet/terraform?ref=v3.1.9"

  enabled          = try(var.apps.broadsheet.enabled, false)
  hostname         = try(var.apps.broadsheet.hostname, "")
  root_admin_email = try(var.apps.broadsheet.root_admin_email, "")
  base             = local.base

  access_level            = try(var.apps.broadsheet.access_level, "admin")
  extra_authorized_groups = try(var.apps.broadsheet.extra_authorized_groups, {})
  tier_cascade_enabled    = try(var.apps.broadsheet.tier_cascade_enabled, true)
  tier_access_level       = try(var.apps.broadsheet.tier_access_level, "admin")
  smtp_from_email         = try(var.apps.broadsheet.smtp_from_email, "")
  oidc_auto_provision     = try(var.apps.broadsheet.oidc_auto_provision, true)
  oidc_allow_magic_code   = try(var.apps.broadsheet.oidc_allow_magic_code, true)
  application_name        = try(var.apps.broadsheet.application_name, "Broadsheet")
  application_slug        = try(var.apps.broadsheet.application_slug, "")
  category_group          = try(var.apps.broadsheet.category_group, "Member Engagement")
  icon_url                = try(var.apps.broadsheet.icon_url, null)
  icon_filename           = try(var.apps.broadsheet.icon_filename, "broadsheet-icon.png")
  monitoring_enabled      = try(var.apps.broadsheet.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.broadsheet.deployment_host_key, "apps")
  bucket_name_override    = try(var.apps.broadsheet.bucket_name_override, "")
  dns_zone_override       = try(var.apps.broadsheet.dns_zone_override, "")

  credentials_preserve = try(var.apps.broadsheet.credentials_preserve, false)
}

# Nextcloud + OnlyOffice + Talk HPB ship as one stack — three hostnames
# (the main UI, the OnlyOffice editor, and the Talk signaling/TURN endpoint).
# Talk HPB needs UDP/TCP 3478 + UDP 49152-49252 open in the security group on
# top of the host firewall — extend default_security_group_extra_inbound_rules
# in module.base accordingly.
module "nextcloud" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/nextcloud/terraform?ref=v3.1.9"

  enabled             = try(var.apps.nextcloud.enabled, false)
  hostname            = try(var.apps.nextcloud.hostname, "")
  onlyoffice_hostname = try(var.apps.nextcloud.onlyoffice_hostname, "")
  talk_hostname       = try(var.apps.nextcloud.talk_hostname, "")
  base                = local.base

  access_level            = try(var.apps.nextcloud.access_level, "member")
  extra_authorized_groups = try(var.apps.nextcloud.extra_authorized_groups, {})
  tier_cascade_enabled    = try(var.apps.nextcloud.tier_cascade_enabled, true)
  tier_access_level       = try(var.apps.nextcloud.tier_access_level, "admin")
  image_tag               = try(var.apps.nextcloud.image_tag, "32-apache")
  admin_username          = try(var.apps.nextcloud.admin_username, "ncadmin")
  default_phone_region    = try(var.apps.nextcloud.default_phone_region, "US")
  max_upload_size_bytes   = try(var.apps.nextcloud.max_upload_size_bytes, 2147483648)
  smtp_from_email         = try(var.apps.nextcloud.smtp_from_email, "")
  application_name        = try(var.apps.nextcloud.application_name, "Nextcloud")
  application_slug        = try(var.apps.nextcloud.application_slug, "")
  category_group          = try(var.apps.nextcloud.category_group, "Collaboration")
  icon_url                = try(var.apps.nextcloud.icon_url, null)
  icon_filename           = try(var.apps.nextcloud.icon_filename, "")
  monitoring_enabled      = try(var.apps.nextcloud.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.nextcloud.deployment_host_key, "apps")
  bucket_name_override    = try(var.apps.nextcloud.bucket_name_override, "")
  dns_zone_override       = try(var.apps.nextcloud.dns_zone_override, "")

  # Resource + branding + per-app knobs. Defaults mirror the bundle's own.
  instance_name            = try(var.apps.nextcloud.instance_name, "Nextcloud")
  maintenance_window_start = try(var.apps.nextcloud.maintenance_window_start, 2)
  enabled_apps = try(var.apps.nextcloud.enabled_apps, [
    "groupfolders", "notify_push", "notes", "tasks", "forms",
    "polls", "epubviewer", "webhook_listeners",
  ])
  disabled_apps        = try(var.apps.nextcloud.disabled_apps, ["photos"])
  n8n_form_webhook_url = try(var.apps.nextcloud.n8n_form_webhook_url, "")

  # OnlyOffice + Talk container tuning.
  onlyoffice_image_tag    = try(var.apps.nextcloud.onlyoffice_image_tag, "latest")
  onlyoffice_memory_limit = try(var.apps.nextcloud.onlyoffice_memory_limit, "2G")
  onlyoffice_cpu_limit    = try(var.apps.nextcloud.onlyoffice_cpu_limit, "2.0")
  talk_image_tag          = try(var.apps.nextcloud.talk_image_tag, "latest")
  talk_turn_port          = try(var.apps.nextcloud.talk_turn_port, 3478)
  talk_relay_port_min     = try(var.apps.nextcloud.talk_relay_port_min, 49152)
  talk_relay_port_max     = try(var.apps.nextcloud.talk_relay_port_max, 49252)
  talk_memory_limit       = try(var.apps.nextcloud.talk_memory_limit, "1G")
  talk_cpu_limit          = try(var.apps.nextcloud.talk_cpu_limit, "1.0")

  credentials_preserve = try(var.apps.nextcloud.credentials_preserve, false)
}

module "decidim" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/decidim/terraform?ref=v3.1.9"

  enabled            = try(var.apps.decidim.enabled, false)
  hostname           = try(var.apps.decidim.hostname, "")
  organization_name  = try(var.apps.decidim.organization_name, "")
  system_admin_email = try(var.apps.decidim.system_admin_email, "")
  base               = local.base

  access_level                  = try(var.apps.decidim.access_level, "member")
  extra_authorized_groups       = try(var.apps.decidim.extra_authorized_groups, {})
  tier_cascade_enabled          = try(var.apps.decidim.tier_cascade_enabled, true)
  tier_access_level             = try(var.apps.decidim.tier_access_level, "admin")
  image_tag                     = try(var.apps.decidim.image_tag, "0.28")
  default_locale                = try(var.apps.decidim.default_locale, "en")
  available_locales             = try(var.apps.decidim.available_locales, ["en"])
  organization_reference_prefix = try(var.apps.decidim.organization_reference_prefix, "")
  organization_admin_email      = try(var.apps.decidim.organization_admin_email, "")
  organization_admin_name       = try(var.apps.decidim.organization_admin_name, "")
  organization_admin_nickname   = try(var.apps.decidim.organization_admin_nickname, "")
  smtp_from_email               = try(var.apps.decidim.smtp_from_email, "")
  sidekiq_concurrency           = try(var.apps.decidim.sidekiq_concurrency, 5)
  application_name              = try(var.apps.decidim.application_name, "Decidim")
  application_slug              = try(var.apps.decidim.application_slug, "")
  category_group                = try(var.apps.decidim.category_group, "Member Engagement")
  icon_url                      = try(var.apps.decidim.icon_url, null)
  icon_filename                 = try(var.apps.decidim.icon_filename, "decidim-icon.png")
  monitoring_enabled            = try(var.apps.decidim.monitoring_enabled, true)
  deployment_host_key           = try(var.apps.decidim.deployment_host_key, "apps")
  bucket_name_override          = try(var.apps.decidim.bucket_name_override, "")
  dns_zone_override             = try(var.apps.decidim.dns_zone_override, "")

  credentials_preserve = try(var.apps.decidim.credentials_preserve, false)
}

# OIDC via an adapter (NOT forward-auth — don't add jitsi.authentik_provider_id
# to extra_forward_auth_provider_ids below). The adapter brokers between
# Authentik's OIDC dance and Jitsi's JWT room-token model.
module "jitsi" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/jitsi/terraform?ref=v3.1.9"

  enabled  = try(var.apps.jitsi.enabled, false)
  hostname = try(var.apps.jitsi.hostname, "")
  base     = local.base

  access_level               = try(var.apps.jitsi.access_level, "member")
  extra_authorized_groups    = try(var.apps.jitsi.extra_authorized_groups, {})
  tier_cascade_enabled       = try(var.apps.jitsi.tier_cascade_enabled, true)
  tier_access_level          = try(var.apps.jitsi.tier_access_level, "admin")
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
  application_name           = try(var.apps.jitsi.application_name, "Video Meetings (Jitsi)")
  application_slug           = try(var.apps.jitsi.application_slug, "")
  category_group             = try(var.apps.jitsi.category_group, "Collaboration")
  icon_url                   = try(var.apps.jitsi.icon_url, null)
  icon_filename              = try(var.apps.jitsi.icon_filename, "")
  monitoring_enabled         = try(var.apps.jitsi.monitoring_enabled, true)
  deployment_host_key        = try(var.apps.jitsi.deployment_host_key, "apps")
  dns_zone_override          = try(var.apps.jitsi.dns_zone_override, "")

  credentials_preserve = try(var.apps.jitsi.credentials_preserve, false)
}

module "espocrm" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/espocrm/terraform?ref=v3.1.9"

  enabled  = try(var.apps.espocrm.enabled, false)
  hostname = try(var.apps.espocrm.hostname, "")
  base     = local.base

  access_level                   = try(var.apps.espocrm.access_level, "member")
  extra_authorized_groups        = try(var.apps.espocrm.extra_authorized_groups, {})
  tier_cascade_enabled           = try(var.apps.espocrm.tier_cascade_enabled, true)
  tier_access_level              = try(var.apps.espocrm.tier_access_level, "admin")
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
  application_name               = try(var.apps.espocrm.application_name, "EspoCRM")
  application_slug               = try(var.apps.espocrm.application_slug, "")
  category_group                 = try(var.apps.espocrm.category_group, "Member Operations")
  icon_url                       = try(var.apps.espocrm.icon_url, null)
  icon_filename                  = try(var.apps.espocrm.icon_filename, "espocrm-icon.png")
  monitoring_enabled             = try(var.apps.espocrm.monitoring_enabled, true)
  deployment_host_key            = try(var.apps.espocrm.deployment_host_key, "apps")
  dns_zone_override              = try(var.apps.espocrm.dns_zone_override, "")

  credentials_preserve = try(var.apps.espocrm.credentials_preserve, false)
}

module "n8n" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/n8n/terraform?ref=v3.1.9"

  enabled  = try(var.apps.n8n.enabled, false)
  hostname = try(var.apps.n8n.hostname, "")
  base     = local.base

  access_level                 = try(var.apps.n8n.access_level, "member")
  extra_authorized_groups      = try(var.apps.n8n.extra_authorized_groups, {})
  tier_cascade_enabled         = try(var.apps.n8n.tier_cascade_enabled, true)
  tier_access_level            = try(var.apps.n8n.tier_access_level, "admin")
  image_tag                    = try(var.apps.n8n.image_tag, "latest")
  n8n_admin_group_name         = try(var.apps.n8n.n8n_admin_group_name, "admin")
  timezone                     = try(var.apps.n8n.timezone, "UTC")
  public_api_disabled          = try(var.apps.n8n.public_api_disabled, true)
  application_name             = try(var.apps.n8n.application_name, "n8n Workflows")
  application_slug             = try(var.apps.n8n.application_slug, "")
  category_group               = try(var.apps.n8n.category_group, "Technical Management")
  icon_url                     = try(var.apps.n8n.icon_url, null)
  icon_filename                = try(var.apps.n8n.icon_filename, "n8n-icon.png")
  service_account_extra_groups = try(var.apps.n8n.service_account_extra_groups, [])
  service_account_extra_group_ids = concat(
    try(var.apps.n8n.service_account_extra_group_ids, []),
    (try(var.apps.broadsheet.enabled, false) && try(var.apps.n8n.broadsheet_membership, true))
    ? [module.broadsheet.authentik_application_group_id]
    : [],
  )
  monitoring_enabled    = try(var.apps.n8n.monitoring_enabled, true)
  deployment_host_key   = try(var.apps.n8n.deployment_host_key, "apps")
  dns_zone_override     = try(var.apps.n8n.dns_zone_override, "")
  extra_docker_networks = try(var.apps.n8n.extra_docker_networks, [])

  # Workflow IDs are populated AFTER first import — capture from n8n UI then re-apply.
  extra_env_vars = merge(
    {
      SLACK_CHANNEL_NEW_SIGNUPS        = try(var.apps.n8n.slack_channel_new_signups, "")
      SLACK_CHANNEL_ADMIN_ALERTS       = try(var.apps.n8n.slack_channel_admin_alerts, "")
      BROADSHEET_WORKSPACE_ID          = try(var.apps.n8n.broadsheet_workspace_id, "")
      BROADSHEET_ALL_MEMBERS_LIST_ID   = try(var.apps.n8n.broadsheet_all_members_list_id, "allmembers")
      BROADSHEET_ALL_MEMBERS_LIST_NAME = try(var.apps.n8n.broadsheet_all_members_list_name, "All Members")
      WORKFLOW_ID_BROADSHEET_SUBSCRIBE = try(var.apps.n8n.workflow_id_broadsheet_subscribe, "")
      WORKFLOW_ID_ESPOCRM_UPSERT       = try(var.apps.n8n.workflow_id_espocrm_upsert, "")
      WORKFLOW_ID_SLACK_INVITE_STUB    = try(var.apps.n8n.workflow_id_slack_invite_stub, "")
    },
    module.broadsheet.enabled ? { BROADSHEET_BASE_URL = module.broadsheet.app_url } : {},
    module.espocrm.enabled ? { ESPOCRM_BASE_URL = module.espocrm.app_url } : {},
    try(var.apps.n8n.extra_env_vars, {}),
  )

  credentials_preserve = try(var.apps.n8n.credentials_preserve, false)
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
    module.broadsheet.backup_plan,
    module.nextcloud.backup_plan,
    module.decidim.backup_plan,
    module.jitsi.backup_plan,
    module.espocrm.backup_plan,
    module.n8n.backup_plan,
    module.prometheus.backup_plan,
    module.loki.backup_plan,
    module.grafana.backup_plan,
    module.wazuh.backup_plan,
  ] : plan if plan != null]

  # Each app's `monitoring` output carries scrape configs, dashboards, log
  # paths, alert rules. Coalesce nulls then split by destination key for the
  # prometheus + grafana + loki bundles to consume.
  _monitoring_contribs = [for c in [
    module.identity.monitoring,
    module.outline.monitoring,
    module.steward.monitoring,
    module.vikunja.monitoring,
    module.bentopdf.monitoring,
    module.privacy_policy.monitoring,
    module.notifuse.monitoring,
    module.broadsheet.monitoring,
    module.nextcloud.monitoring,
    module.decidim.monitoring,
    module.jitsi.monitoring,
    module.espocrm.monitoring,
    module.n8n.monitoring,
    module.prometheus.monitoring,
    module.grafana.monitoring,
    module.wazuh.monitoring,         # blackbox_targets — peer-flagged drop
    module.backrest_mgmt.monitoring, # prometheus_scrape_configs (backrest /metrics)
    module.diun_mgmt.monitoring,     # loki_log_paths
  ] : c if c != null]

  # Normalize every per-bundle scrape entry to a canonical shape before flatten.
  # Terraform requires homogeneous list element types, and bundles emit entries
  # with optional fields (scheme/metrics_path absent, labels absent or with
  # varying keys). Rebuild each entry through the same expression so every
  # element ends up at the same object type:
  #
  #   { job_name, scheme, metrics_path, static_configs: [{ targets, labels: map(string) }] }
  #
  # Bundles emitting new scrape entries just need job_name + static_configs;
  # the rest default sensibly. Scrape entries using non-static SDs (file_sd,
  # dns_sd, etc.) aren't supported by this normalizer yet — add handling
  # here when the first bundle needs it.
  aggregated_scrape_configs = flatten([
    for c in local._monitoring_contribs : [
      for entry in try(c.prometheus_scrape_configs, []) : {
        job_name     = entry.job_name
        scheme       = try(entry.scheme, "http")
        metrics_path = try(entry.metrics_path, "/metrics")
        static_configs = [
          for sc in try(entry.static_configs, []) : {
            targets = sc.targets
            labels  = { for k, v in try(sc.labels, {}) : k => tostring(v) }
          }
        ]
      }
    ]
  ])
  aggregated_alert_rules = flatten([
    for c in local._monitoring_contribs : try(c.alert_rules, [])
  ])
  aggregated_blackbox_targets = distinct(flatten([
    for c in local._monitoring_contribs : try(c.blackbox_targets, [])
  ]))
  # Each entry in monitoring.grafana_dashboards is an absolute path to a JSON
  # file in the consumer's .terraform module cache. Read contents here so the
  # grafana role can write the files with no ansible-side path juggling.
  _aggregated_dashboard_paths = flatten([
    for c in local._monitoring_contribs : try(c.grafana_dashboards, [])
  ])
  aggregated_grafana_dashboards = [
    for p in local._aggregated_dashboard_paths : {
      filename = basename(p)
      contents = file(p)
    }
  ]

  # Split-DNS overrides — each bundle declares its public hostname(s)
  # alongside the private IP of its deployment host. The base split-dns
  # ansible role consumes the rolled-up map and renders dnsmasq overrides
  # on every host. Auto-disabled (empty map) for single-host topologies:
  # one host means everything is either on the same docker network or
  # 127.0.0.1, no split-horizon needed.
  _split_dns_contribs = flatten([
    module.outline.split_dns_entries,
    module.steward.split_dns_entries,
    module.vikunja.split_dns_entries,
    module.bentopdf.split_dns_entries,
    module.privacy_policy.split_dns_entries,
    module.notifuse.split_dns_entries,
    module.broadsheet.split_dns_entries,
    module.nextcloud.split_dns_entries,
    module.decidim.split_dns_entries,
    module.jitsi.split_dns_entries,
    module.espocrm.split_dns_entries,
    module.n8n.split_dns_entries,
    module.backrest_mgmt.split_dns_entries,
    module.grafana.split_dns_entries,
    module.wazuh.split_dns_entries,
  ])
  split_dns_overrides = (
    length(module.base.compute.hosts) > 1
    ? { for e in local._split_dns_contribs : e.hostname => e.private_ip }
    : {}
  )
}

# ── Monitoring stack (typically all on the same host) ──────────────────────
# Prometheus + Loki + Grafana share the monitoring_internal docker network
# (each role creates it idempotently). Grafana's datasources point at
# http://prometheus:9090 and http://loki:3100 by default.

module "prometheus" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/prometheus/terraform?ref=v3.1.9"

  enabled = try(var.apps.prometheus.enabled, false)
  base    = local.base

  deployment_host_key  = try(var.apps.prometheus.deployment_host_key, "management")
  retention            = try(var.apps.prometheus.retention, "30d")
  exporters_enabled    = try(var.apps.prometheus.exporters_enabled, true)
  remote_write_enabled = try(var.apps.prometheus.remote_write_enabled, true)
  private_ip_bind      = try(var.apps.prometheus.private_ip_bind, "")
  # Auto-aggregated from every enabled app's monitoring.prometheus_scrape_configs
  # + monitoring.alert_rules + monitoring.blackbox_targets.
  scrape_configs       = concat(local.aggregated_scrape_configs, try(var.apps.prometheus.scrape_configs, []))
  alert_rules          = concat(local.aggregated_alert_rules, try(var.apps.prometheus.alert_rules, []))
  blackbox_targets     = concat(local.aggregated_blackbox_targets, try(var.apps.prometheus.blackbox_targets, []))
  extra_scrape_targets = try(var.apps.prometheus.extra_scrape_targets, {})

  # Blackbox exporter sidecar — actively probes every public hostname on the
  # platform. Opt-out per the plug-and-play-owns-networking philosophy.
  blackbox_exporter_enabled = try(var.apps.prometheus.blackbox_exporter_enabled, true)

  # Scaleway TEM exporter sidecar — pairs with the bundled scaleway-tem
  # dashboard + alert rules. Reuses the smtp-config secret base writes
  # (its `password` field IS a TEM-scoped Scaleway API key).
  tem_exporter_enabled               = try(var.apps.prometheus.tem_exporter_enabled, false)
  tem_smtp_secret_id                 = try(local.base.scaleway.smtp_config_secret_id, "")
  tem_scaleway_project_id            = local.base.scaleway.project_id
  tem_scaleway_region                = local.base.scaleway.region
  tem_exporter_poll_interval_seconds = try(var.apps.prometheus.tem_exporter_poll_interval_seconds, 60)
  tem_exporter_lookback_minutes      = try(var.apps.prometheus.tem_exporter_lookback_minutes, 60)
}

module "loki" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/loki/terraform?ref=v3.1.9"

  enabled = try(var.apps.loki.enabled, false)
  base    = local.base

  deployment_host_key     = try(var.apps.loki.deployment_host_key, "management")
  retention               = try(var.apps.loki.retention, "744h")
  ingestion_rate_mb       = try(var.apps.loki.ingestion_rate_mb, 10)
  ingestion_burst_size_mb = try(var.apps.loki.ingestion_burst_size_mb, 20)
  private_ip_bind         = try(var.apps.loki.private_ip_bind, "")
}

module "wazuh" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/wazuh/terraform?ref=v3.1.9"

  enabled  = try(var.apps.wazuh.enabled, false)
  hostname = try(var.apps.wazuh.hostname, "")
  base     = local.base

  access_level            = try(var.apps.wazuh.access_level, "admin")
  extra_authorized_groups = try(var.apps.wazuh.extra_authorized_groups, {})
  tier_cascade_enabled    = try(var.apps.wazuh.tier_cascade_enabled, true)
  tier_access_level       = try(var.apps.wazuh.tier_access_level, "admin")
  deployment_host_key     = try(var.apps.wazuh.deployment_host_key, "management")
  release_version         = try(var.apps.wazuh.release_version, "4.9.0")
  indexer_heap_size       = try(var.apps.wazuh.indexer_heap_size, "1g")
  oidc_admin_group        = try(var.apps.wazuh.oidc_admin_group, "admin")
  application_name        = try(var.apps.wazuh.application_name, "Wazuh")
  application_slug        = try(var.apps.wazuh.application_slug, "")
  category_group          = try(var.apps.wazuh.category_group, "Technical Management")
  icon_url                = try(var.apps.wazuh.icon_url, null)
  icon_filename           = try(var.apps.wazuh.icon_filename, "")
  dns_zone_override       = try(var.apps.wazuh.dns_zone_override, "")

  # Manager listening ports — wazuh-agent bundles connect on these.
  manager_agent_port      = try(var.apps.wazuh.manager_agent_port, 1514)
  manager_enrollment_port = try(var.apps.wazuh.manager_enrollment_port, 1515)
  manager_syslog_port     = try(var.apps.wazuh.manager_syslog_port, 514)

  credentials_preserve = try(var.apps.wazuh.credentials_preserve, false)
}

module "grafana" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/grafana/terraform?ref=v3.1.9"

  enabled  = try(var.apps.grafana.enabled, false)
  hostname = try(var.apps.grafana.hostname, "")
  base     = local.base

  access_level            = try(var.apps.grafana.access_level, "admin")
  extra_authorized_groups = try(var.apps.grafana.extra_authorized_groups, {})
  tier_cascade_enabled    = try(var.apps.grafana.tier_cascade_enabled, true)
  tier_access_level       = try(var.apps.grafana.tier_access_level, "admin")
  deployment_host_key     = try(var.apps.grafana.deployment_host_key, "management")
  plugins                 = try(var.apps.grafana.plugins, [])
  oidc_admin_group        = try(var.apps.grafana.oidc_admin_group, "admin")
  oidc_editor_group       = try(var.apps.grafana.oidc_editor_group, "manager")
  application_name        = try(var.apps.grafana.application_name, "Grafana")
  application_slug        = try(var.apps.grafana.application_slug, "")
  category_group          = try(var.apps.grafana.category_group, "Technical Management")
  icon_url                = try(var.apps.grafana.icon_url, null)
  icon_filename           = try(var.apps.grafana.icon_filename, "grafana-icon.png")
  # Auto-aggregated from every enabled app's monitoring.grafana_dashboards
  # plus any consumer-supplied extras.
  grafana_dashboards = concat(
    local.aggregated_grafana_dashboards,
    try(var.apps.grafana.grafana_dashboards, []),
  )

  dns_zone_override = try(var.apps.grafana.dns_zone_override, "")

  # Datasource URLs + JSM alerting plumbing. Bundle vars are non-nullable
  # strings/maps, so the try() fallback restates the bundle defaults rather
  # than passing null. prometheus_url / loki_url defaults assume prometheus
  # and loki are co-deployed on the same host and share the bundle's docker
  # network; override per-consumer when shipping to external backends.
  prometheus_url             = try(var.apps.grafana.prometheus_url, "http://prometheus:9090")
  loki_url                   = try(var.apps.grafana.loki_url, "http://loki:3100")
  prometheus_scrape_interval = try(var.apps.grafana.prometheus_scrape_interval, "30s")
  jsm_api_key_secret_id      = try(var.apps.grafana.jsm_api_key_secret_id, "")
  jsm_api_region             = try(var.apps.grafana.jsm_api_region, "us")
  jsm_priority_mapping       = try(var.apps.grafana.jsm_priority_mapping, { critical = "P1", warning = "P3", info = "P5" })
  jsm_alert_tags             = try(var.apps.grafana.jsm_alert_tags, ["sabokit"])

  credentials_preserve = try(var.apps.grafana.credentials_preserve, false)
}

# Backrest is multi-instance: each backed-up host gets its own module block,
# its own bucket, its own restic repo. Forward-auth — its provider_id MUST
# be added to identity's extra_forward_auth_provider_ids list (see identity.tf).
# Example: a single "mgmt" instance. Add more module blocks for each host.
module "backrest_mgmt" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/backrest/terraform?ref=v3.1.9"

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
  tier_cascade_enabled                  = try(var.apps.backrest_mgmt.tier_cascade_enabled, true)
  tier_access_level                     = try(var.apps.backrest_mgmt.tier_access_level, "admin")
  image_tag                             = try(var.apps.backrest_mgmt.image_tag, "latest")
  backup_sources                        = try(var.apps.backrest_mgmt.backup_sources, {})
  restic_prune_max_frequency_days       = try(var.apps.backrest_mgmt.restic_prune_max_frequency_days, 7)
  restic_check_max_frequency_days       = try(var.apps.backrest_mgmt.restic_check_max_frequency_days, 30)
  restic_check_read_data_subset_percent = try(var.apps.backrest_mgmt.restic_check_read_data_subset_percent, 5)
  application_name                      = try(var.apps.backrest_mgmt.application_name, "")
  category_group                        = try(var.apps.backrest_mgmt.category_group, "Technical Management")
  icon_url                              = try(var.apps.backrest_mgmt.icon_url, null)
  icon_filename                         = try(var.apps.backrest_mgmt.icon_filename, "")
  monitoring_enabled                    = try(var.apps.backrest_mgmt.monitoring_enabled, true)
  deployment_host_key                   = try(var.apps.backrest_mgmt.deployment_host_key, "apps")
  bucket_name_override                  = try(var.apps.backrest_mgmt.bucket_name_override, "")
  dns_zone_override                     = try(var.apps.backrest_mgmt.dns_zone_override, "")

  credentials_preserve = try(var.apps.backrest_mgmt.credentials_preserve, false)
}

# ── Platform host-services (one container per host) ─────────────────────────
# Watchtower auto-updates opted-in app containers; Autoheal restarts unhealthy
# ones. Multi-instance like backrest — one block per host you want them on.
# Each app bundle's per-app `auto_update_enabled` / `autoheal_enabled` knobs
# decide which containers are labelled for these to act on.

module "watchtower_apps" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/watchtower/terraform?ref=v3.1.9"

  enabled = try(var.apps.watchtower_apps.enabled, false)
  base    = local.base

  deployment_host_key         = try(var.apps.watchtower_apps.deployment_host_key, "apps")
  image_tag                   = try(var.apps.watchtower_apps.image_tag, "latest")
  schedule                    = try(var.apps.watchtower_apps.schedule, "0 0 4 * * *")
  notifications_slack_webhook = try(var.apps.watchtower_apps.notifications_slack_webhook, "")
}

# Diun — notify-on-new-image companion (or replacement) for Watchtower.
# Multi-instance like backrest: one block per host you want notification
# coverage on. Convention: a single "mgmt" instance on the management host
# covers a small fleet; large fleets get one per host. See platform/apps/diun.
module "diun_mgmt" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/diun/terraform?ref=v3.1.9"

  enabled       = try(var.apps.diun_mgmt.enabled, false)
  instance_name = try(var.apps.diun_mgmt.instance_name, "mgmt")
  base          = local.base

  deployment_host_key     = try(var.apps.diun_mgmt.deployment_host_key, "management")
  image_tag               = try(var.apps.diun_mgmt.image_tag, "4.31.0")
  timezone                = try(var.apps.diun_mgmt.timezone, "UTC")
  watch_schedule          = try(var.apps.diun_mgmt.watch_schedule, "0 0 6 * * *")
  watch_workers           = try(var.apps.diun_mgmt.watch_workers, 10)
  watch_first_check_notif = try(var.apps.diun_mgmt.watch_first_check_notif, false)
  watch_by_default        = try(var.apps.diun_mgmt.watch_by_default, true)
  default_watch_repo      = try(var.apps.diun_mgmt.default_watch_repo, false)
  include_swarm_services  = try(var.apps.diun_mgmt.include_swarm_services, false)
  notification_targets    = try(var.apps.diun_mgmt.notification_targets, [])
  auto_update_enabled     = try(var.apps.diun_mgmt.auto_update_enabled, false)
  autoheal_enabled        = try(var.apps.diun_mgmt.autoheal_enabled, true)
  monitoring_enabled      = try(var.apps.diun_mgmt.monitoring_enabled, true)
}

# Wazuh agent — host-network container that ships logs to the wazuh manager.
# Multi-instance: copy this block per host you want monitored, swap the
# `wazuh_agent_apps` key + the deployment_host_key.
module "wazuh_agent_apps" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/wazuh-agent/terraform?ref=v3.1.9"

  enabled              = try(var.apps.wazuh_agent_apps.enabled, false)
  base                 = local.base
  deployment_host_key  = try(var.apps.wazuh_agent_apps.deployment_host_key, "apps")
  manager_address      = try(var.apps.wazuh_agent_apps.manager_address, "")
  agent_name           = try(var.apps.wazuh_agent_apps.agent_name, "")
  release_version      = try(var.apps.wazuh_agent_apps.release_version, "4.9.0")
  fim_enabled          = try(var.apps.wazuh_agent_apps.fim_enabled, true)
  fim_extra_paths      = try(var.apps.wazuh_agent_apps.fim_extra_paths, [])
  fim_extra_exclusions = try(var.apps.wazuh_agent_apps.fim_extra_exclusions, [])
}

# ProtonMail Bridge — IMAP inbound mail for apps that fetch (n8n workflows,
# etc). SMTP outbound stays on TEM at the base tier. Lives in
# platform/bootstrap/ rather than platform/apps/ — it's a host-service the
# rest of the stack depends on, not a user-facing app.
module "protonmail_bridge" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/bootstrap/protonmail-bridge/terraform?ref=v3.1.9"

  enabled = try(var.bootstrap.protonmail_bridge.enabled, false)
  base    = local.base

  # imap_username + bridge_login_secret_id are required when enabled = true.
  # try() with a placeholder lets the module type-check when disabled; the
  # bundle's `count = var.enabled ? 1 : 0` gating means the values are never
  # consumed in that case.
  imap_username          = try(var.bootstrap.protonmail_bridge.imap_username, "")
  bridge_login_secret_id = try(var.bootstrap.protonmail_bridge.bridge_login_secret_id, "")

  deployment_host_key     = try(var.bootstrap.protonmail_bridge.deployment_host_key, "management")
  image_tag               = try(var.bootstrap.protonmail_bridge.image_tag, "latest")
  timezone                = try(var.bootstrap.protonmail_bridge.timezone, "UTC")
  imap_config_secret_name = try(var.bootstrap.protonmail_bridge.imap_config_secret_name, "imap-config")
  auto_update_enabled     = try(var.bootstrap.protonmail_bridge.auto_update_enabled, false)
  autoheal_enabled        = try(var.bootstrap.protonmail_bridge.autoheal_enabled, true)
}

module "autoheal_apps" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/autoheal/terraform?ref=v3.1.9"

  enabled = try(var.apps.autoheal_apps.enabled, false)
  base    = local.base

  deployment_host_key  = try(var.apps.autoheal_apps.deployment_host_key, "apps")
  image_tag            = try(var.apps.autoheal_apps.image_tag, "latest")
  interval_seconds     = try(var.apps.autoheal_apps.interval_seconds, 5)
  start_period_seconds = try(var.apps.autoheal_apps.start_period_seconds, 60)
}
