# Application-tier composition. One module per user-facing app plus the embedded
# forward-auth outpost. Each app is gated by var.<app>.enabled (default false).
#
# Per-app monitoring, backup plans, and split-dns are pushed to the operations
# host by each bundle's ansible at deploy time — there is no cross-layer TF
# aggregation here.

# The data-source contract: rebuilds `base` ({scaleway, compute, domains,
# authentik}) from the infra + identity layers by name/tag. Every app consumes
# module.base.base as its var.base. The authentik provider these modules need is
# configured at the consumer root and inherited here.
module "base" {
  source = "../../_shared/contract"

  org_slug    = var.org_slug
  environment = var.environment

  scaleway_project_id = var.scaleway_project_id
  scaleway_region     = var.scaleway_region
  scaleway_zone       = var.scaleway_zone

  private_network_subnet = var.private_network_subnet
  postgres_enabled       = var.postgres_enabled
  postgres_engine        = var.postgres_engine

  base_domain     = var.base_domain
  mgmt_domain     = var.mgmt_domain
  identity_domain = var.identity_domain

  smtp_secret_name = var.smtp_secret_name
  icon_base_url    = var.icon_base_url
  group_names      = var.group_names

  compute_hosts = {
    for k, h in var.compute_hosts : k => {
      role           = h.role
      ansible_group  = try(h.ansible_group, "")
      ansible_groups = try(h.ansible_groups, [])
    }
  }
}

module "outline" {
  source = "../outline/terraform"

  enabled           = try(var.outline.enabled, false)
  hostname          = try(var.outline.hostname, "")
  base              = module.base.base
  authorized_groups = try(var.outline.authorized_groups, ["member"])

  # Optional overrides
  smtp_from_email      = try(var.outline.smtp_from_email, "")
  application_name     = try(var.outline.application_name, "Wiki (Outline)")
  application_slug     = try(var.outline.application_slug, "")
  category_group       = try(var.outline.category_group, "Collaboration")
  icon_url             = try(var.outline.icon_url, "")
  icon_filename        = try(var.outline.icon_filename, "outline-icon.png")
  monitoring_enabled   = try(var.outline.monitoring_enabled, true)
  deployment_host_key  = try(var.outline.deployment_host_key, "tools")
  bucket_name_override = try(var.outline.bucket_name_override, "")
  dns_zone_override    = try(var.outline.dns_zone_override, "")

  extra_docker_networks = try(var.outline.extra_docker_networks, [])
}

module "steward" {
  source = "../steward/terraform"

  enabled           = try(var.steward.enabled, false)
  hostname          = try(var.steward.hostname, "")
  base              = module.base.base
  authorized_groups = try(var.steward.authorized_groups, ["delegate"])

  # Optional overrides
  admin_group_name             = try(var.steward.admin_group_name, "union-delegate")
  invite_flow_slug             = try(var.steward.invite_flow_slug, "")
  image_repository             = try(var.steward.image_repository, "ghcr.io/sheyaln/sabokit-steward")
  image_tag                    = try(var.steward.image_tag, "latest")
  application_name             = try(var.steward.application_name, "Steward")
  application_slug             = try(var.steward.application_slug, "")
  category_group               = try(var.steward.category_group, "Member Operations")
  icon_url                     = try(var.steward.icon_url, "")
  icon_filename                = try(var.steward.icon_filename, "steward-icon.png")
  service_account_extra_groups = try(var.steward.service_account_extra_groups, [])
  monitoring_enabled           = try(var.steward.monitoring_enabled, true)
  deployment_host_key          = try(var.steward.deployment_host_key, "tools")
  dns_zone_override            = try(var.steward.dns_zone_override, "")

  extra_env_vars        = try(var.steward.extra_env_vars, {})
  extra_docker_networks = try(var.steward.extra_docker_networks, [])
}

module "vikunja" {
  source = "../vikunja/terraform"

  enabled           = try(var.vikunja.enabled, false)
  hostname          = try(var.vikunja.hostname, "")
  base              = module.base.base
  authorized_groups = try(var.vikunja.authorized_groups, ["member"])

  # Optional overrides
  timezone               = try(var.vikunja.timezone, "UTC")
  enable_registration    = try(var.vikunja.enable_registration, false)
  enable_local_auth      = try(var.vikunja.enable_local_auth, false)
  smtp_from_email        = try(var.vikunja.smtp_from_email, "")
  oidc_groups_scope_name = try(var.vikunja.oidc_groups_scope_name, "vikunja_scope")
  application_name       = try(var.vikunja.application_name, "Tasks (Vikunja)")
  application_slug       = try(var.vikunja.application_slug, "")
  category_group         = try(var.vikunja.category_group, "Collaboration")
  icon_url               = try(var.vikunja.icon_url, "")
  icon_filename          = try(var.vikunja.icon_filename, "vikunja-icon.png")
  monitoring_enabled     = try(var.vikunja.monitoring_enabled, true)
  deployment_host_key    = try(var.vikunja.deployment_host_key, "tools")
  dns_zone_override      = try(var.vikunja.dns_zone_override, "")

  extra_env_vars        = try(var.vikunja.extra_env_vars, {})
  extra_docker_networks = try(var.vikunja.extra_docker_networks, [])
}

# Forward-auth app (no OIDC). Its provider_id MUST also be added to the
# identity module's extra_forward_auth_provider_ids list — see identity.tf.

module "bentopdf" {
  source = "../bentopdf/terraform"

  enabled           = try(var.bentopdf.enabled, false)
  hostname          = try(var.bentopdf.hostname, "")
  base              = module.base.base
  authorized_groups = try(var.bentopdf.authorized_groups, ["member"])

  # Optional overrides
  image                 = try(var.bentopdf.image, "ghcr.io/digital-blueprint/bento-pdf:latest")
  application_name      = try(var.bentopdf.application_name, "PDF Tools (BentoPDF)")
  application_slug      = try(var.bentopdf.application_slug, "")
  category_group        = try(var.bentopdf.category_group, "Collaboration")
  icon_url              = try(var.bentopdf.icon_url, "")
  icon_filename         = try(var.bentopdf.icon_filename, "bentopdf-icon.png")
  monitoring_enabled    = try(var.bentopdf.monitoring_enabled, true)
  deployment_host_key   = try(var.bentopdf.deployment_host_key, "tools")
  dns_zone_override     = try(var.bentopdf.dns_zone_override, "")
  extra_docker_networks = try(var.bentopdf.extra_docker_networks, [])
}

# Public — no auth integration. Privacy policies must be reachable without login.

module "privacy_policy" {
  source = "../privacy-policy/terraform"

  enabled  = try(var.privacy_policy.enabled, false)
  hostname = try(var.privacy_policy.hostname, "")
  base     = module.base.base

  page_title            = try(var.privacy_policy.page_title, "Privacy Policy")
  monitoring_enabled    = try(var.privacy_policy.monitoring_enabled, true)
  deployment_host_key   = try(var.privacy_policy.deployment_host_key, "tools")
  dns_zone_override     = try(var.privacy_policy.dns_zone_override, "")
  extra_docker_networks = try(var.privacy_policy.extra_docker_networks, [])
}

# Broadsheet — sabokit-broadsheet fork of notifuse. Replaces the dropped
# notifuse bundle (removed v3.3.0). Internal docker service name and Traefik
# labels were renamed at v3.2.1; consumers cutting over from notifuse should
# export storage state before destroying the old bundle.

module "broadsheet" {
  source = "../broadsheet/terraform"

  enabled           = try(var.broadsheet.enabled, false)
  hostname          = try(var.broadsheet.hostname, "")
  root_admin_email  = try(var.broadsheet.root_admin_email, "")
  base              = module.base.base
  authorized_groups = try(var.broadsheet.authorized_groups, ["delegate"])

  smtp_from_email       = try(var.broadsheet.smtp_from_email, "")
  oidc_auto_provision   = try(var.broadsheet.oidc_auto_provision, true)
  oidc_allow_magic_code = try(var.broadsheet.oidc_allow_magic_code, false)
  application_name      = try(var.broadsheet.application_name, "Broadsheet")
  application_slug      = try(var.broadsheet.application_slug, "")
  category_group        = try(var.broadsheet.category_group, "Member Engagement")
  icon_url              = try(var.broadsheet.icon_url, "")
  icon_filename         = try(var.broadsheet.icon_filename, "broadsheet-icon.png")
  monitoring_enabled    = try(var.broadsheet.monitoring_enabled, true)
  deployment_host_key   = try(var.broadsheet.deployment_host_key, "tools")
  bucket_name_override  = try(var.broadsheet.bucket_name_override, "")
  dns_zone_override     = try(var.broadsheet.dns_zone_override, "")

  extra_env_vars        = try(var.broadsheet.extra_env_vars, {})
  extra_docker_networks = try(var.broadsheet.extra_docker_networks, [])
}

# Nextcloud + OnlyOffice + Talk HPB ship as one stack — three hostnames
# (the main UI, the OnlyOffice editor, and the Talk signaling/TURN endpoint).
# Talk HPB needs UDP/TCP 3478 + UDP 49152-49252 open in the security group on
# top of the host firewall — extend default_security_group_extra_inbound_rules
# in module.base accordingly.

module "nextcloud" {
  source = "../nextcloud/terraform"

  enabled             = try(var.nextcloud.enabled, false)
  hostname            = try(var.nextcloud.hostname, "")
  onlyoffice_hostname = try(var.nextcloud.onlyoffice_hostname, "")
  talk_hostname       = try(var.nextcloud.talk_hostname, "")
  base                = module.base.base
  authorized_groups   = try(var.nextcloud.authorized_groups, ["member"])

  image_tag             = try(var.nextcloud.image_tag, "32-apache")
  admin_username        = try(var.nextcloud.admin_username, "ncadmin")
  default_phone_region  = try(var.nextcloud.default_phone_region, "US")
  max_upload_size_bytes = try(var.nextcloud.max_upload_size_bytes, 2147483648)
  smtp_from_email       = try(var.nextcloud.smtp_from_email, "")
  application_name      = try(var.nextcloud.application_name, "Nextcloud")
  application_slug      = try(var.nextcloud.application_slug, "")
  category_group        = try(var.nextcloud.category_group, "Collaboration")
  icon_url              = try(var.nextcloud.icon_url, "")
  icon_filename         = try(var.nextcloud.icon_filename, "nextcloud-icon.png")
  monitoring_enabled    = try(var.nextcloud.monitoring_enabled, true)
  deployment_host_key   = try(var.nextcloud.deployment_host_key, "tools")
  bucket_name_override  = try(var.nextcloud.bucket_name_override, "")
  dns_zone_override     = try(var.nextcloud.dns_zone_override, "")

  # Resource + branding + per-app knobs. Defaults mirror the bundle's own.
  instance_name            = try(var.nextcloud.instance_name, "Nextcloud")
  maintenance_window_start = try(var.nextcloud.maintenance_window_start, 2)
  enabled_apps = try(var.nextcloud.enabled_apps, [
    "groupfolders", "notify_push", "notes", "tasks", "forms",
    "polls", "epubviewer", "webhook_listeners",
  ])
  disabled_apps        = try(var.nextcloud.disabled_apps, ["photos"])
  n8n_form_webhook_url = try(var.nextcloud.n8n_form_webhook_url, "")

  # OnlyOffice + Talk container tuning.
  onlyoffice_image_tag    = try(var.nextcloud.onlyoffice_image_tag, "latest")
  onlyoffice_memory_limit = try(var.nextcloud.onlyoffice_memory_limit, "2G")
  onlyoffice_cpu_limit    = try(var.nextcloud.onlyoffice_cpu_limit, "2.0")
  talk_image_tag          = try(var.nextcloud.talk_image_tag, "latest")
  talk_turn_port          = try(var.nextcloud.talk_turn_port, 3478)
  talk_relay_port_min     = try(var.nextcloud.talk_relay_port_min, 49152)
  talk_relay_port_max     = try(var.nextcloud.talk_relay_port_max, 49252)
  talk_memory_limit       = try(var.nextcloud.talk_memory_limit, "1G")
  talk_cpu_limit          = try(var.nextcloud.talk_cpu_limit, "1.0")

  extra_env_vars        = try(var.nextcloud.extra_env_vars, {})
  extra_docker_networks = try(var.nextcloud.extra_docker_networks, [])
}

module "decidim" {
  source = "../decidim/terraform"

  enabled            = try(var.decidim.enabled, false)
  hostname           = try(var.decidim.hostname, "")
  organization_name  = try(var.decidim.organization_name, "")
  system_admin_email = try(var.decidim.system_admin_email, "")
  base               = module.base.base
  authorized_groups  = try(var.decidim.authorized_groups, ["member"])

  image_tag                     = try(var.decidim.image_tag, "0.28")
  default_locale                = try(var.decidim.default_locale, "en")
  available_locales             = try(var.decidim.available_locales, ["en"])
  organization_reference_prefix = try(var.decidim.organization_reference_prefix, "")
  organization_admin_email      = try(var.decidim.organization_admin_email, "")
  organization_admin_name       = try(var.decidim.organization_admin_name, "")
  organization_admin_nickname   = try(var.decidim.organization_admin_nickname, "")
  smtp_from_email               = try(var.decidim.smtp_from_email, "")
  sidekiq_concurrency           = try(var.decidim.sidekiq_concurrency, 5)
  application_name              = try(var.decidim.application_name, "Decidim")
  application_slug              = try(var.decidim.application_slug, "")
  category_group                = try(var.decidim.category_group, "Member Engagement")
  icon_url                      = try(var.decidim.icon_url, "")
  icon_filename                 = try(var.decidim.icon_filename, "decidim-icon.png")
  monitoring_enabled            = try(var.decidim.monitoring_enabled, true)
  deployment_host_key           = try(var.decidim.deployment_host_key, "tools")
  bucket_name_override          = try(var.decidim.bucket_name_override, "")
  dns_zone_override             = try(var.decidim.dns_zone_override, "")

  extra_env_vars        = try(var.decidim.extra_env_vars, {})
  extra_docker_networks = try(var.decidim.extra_docker_networks, [])
}

# OIDC via an adapter (NOT forward-auth — don't add jitsi.authentik_provider_id
# to extra_forward_auth_provider_ids below). The adapter brokers between
# Authentik's OIDC dance and Jitsi's JWT room-token model.

module "jitsi" {
  source = "../jitsi/terraform"

  enabled           = try(var.jitsi.enabled, false)
  hostname          = try(var.jitsi.hostname, "")
  base              = module.base.base
  authorized_groups = try(var.jitsi.authorized_groups, ["member"])

  image_tag                  = try(var.jitsi.image_tag, "stable-9823")
  timezone                   = try(var.jitsi.timezone, "UTC")
  jvb_udp_port               = try(var.jitsi.jvb_udp_port, 10000)
  jvb_stun_servers           = try(var.jitsi.jvb_stun_servers, "meet-jit-si-turnrelay.jitsi.net:443")
  enable_lobby               = try(var.jitsi.enable_lobby, true)
  enable_breakout_rooms      = try(var.jitsi.enable_breakout_rooms, true)
  enable_prejoin_page        = try(var.jitsi.enable_prejoin_page, true)
  oidc_adapter_image_repo    = try(var.jitsi.oidc_adapter_image_repo, "https://github.com/sabokit/jitsi-oidc-adapter.git")
  oidc_adapter_image_version = try(var.jitsi.oidc_adapter_image_version, "main")
  oidc_log_level             = try(var.jitsi.oidc_log_level, "INFO")
  application_name           = try(var.jitsi.application_name, "Video Meetings (Jitsi)")
  application_slug           = try(var.jitsi.application_slug, "")
  category_group             = try(var.jitsi.category_group, "Collaboration")
  icon_url                   = try(var.jitsi.icon_url, "")
  icon_filename              = try(var.jitsi.icon_filename, "jitsi-icon.png")
  monitoring_enabled         = try(var.jitsi.monitoring_enabled, true)
  deployment_host_key        = try(var.jitsi.deployment_host_key, "tools")
  dns_zone_override          = try(var.jitsi.dns_zone_override, "")

  extra_env_vars        = try(var.jitsi.extra_env_vars, {})
  extra_docker_networks = try(var.jitsi.extra_docker_networks, [])
}

module "espocrm" {
  source = "../espocrm/terraform"

  enabled           = try(var.espocrm.enabled, false)
  hostname          = try(var.espocrm.hostname, "")
  base              = module.base.base
  authorized_groups = try(var.espocrm.authorized_groups, ["delegate"])

  image_tag                      = try(var.espocrm.image_tag, "8.5")
  timezone                       = try(var.espocrm.timezone, "UTC")
  admin_username                 = try(var.espocrm.admin_username, "admin")
  b2c_mode                       = try(var.espocrm.b2c_mode, true)
  oidc_username_claim            = try(var.espocrm.oidc_username_claim, "preferred_username")
  oidc_group_claim               = try(var.espocrm.oidc_group_claim, "groups")
  oidc_team_id_prefix            = try(var.espocrm.oidc_team_id_prefix, "sso-")
  oidc_group_role_mapping        = try(var.espocrm.oidc_group_role_mapping, {})
  enable_member_entity_bootstrap = try(var.espocrm.enable_member_entity_bootstrap, false)
  member_entity_webhooks         = try(var.espocrm.member_entity_webhooks, [])
  application_name               = try(var.espocrm.application_name, "EspoCRM")
  application_slug               = try(var.espocrm.application_slug, "")
  category_group                 = try(var.espocrm.category_group, "Member Operations")
  icon_url                       = try(var.espocrm.icon_url, "")
  icon_filename                  = try(var.espocrm.icon_filename, "espocrm-icon.png")
  monitoring_enabled             = try(var.espocrm.monitoring_enabled, true)
  deployment_host_key            = try(var.espocrm.deployment_host_key, "tools")
  dns_zone_override              = try(var.espocrm.dns_zone_override, "")

  extra_env_vars        = try(var.espocrm.extra_env_vars, {})
  extra_docker_networks = try(var.espocrm.extra_docker_networks, [])
}

module "n8n" {
  source = "../n8n/terraform"

  enabled           = try(var.n8n.enabled, false)
  hostname          = try(var.n8n.hostname, "")
  base              = module.base.base
  authorized_groups = try(var.n8n.authorized_groups, ["admin"])

  image_tag                    = try(var.n8n.image_tag, "latest")
  n8n_admin_group_name         = try(var.n8n.n8n_admin_group_name, "admin")
  timezone                     = try(var.n8n.timezone, "UTC")
  public_api_disabled          = try(var.n8n.public_api_disabled, true)
  application_name             = try(var.n8n.application_name, "n8n Workflows")
  application_slug             = try(var.n8n.application_slug, "")
  category_group               = try(var.n8n.category_group, "Technical Management")
  icon_url                     = try(var.n8n.icon_url, "")
  icon_filename                = try(var.n8n.icon_filename, "n8n-icon.png")
  service_account_extra_groups = try(var.n8n.service_account_extra_groups, [])
  service_account_extra_group_ids = concat(
    try(var.n8n.service_account_extra_group_ids, []),
    (try(var.broadsheet.enabled, false) && try(var.n8n.broadsheet_membership, true))
    ? [module.broadsheet.authentik_application_group_id]
    : [],
  )
  monitoring_enabled    = try(var.n8n.monitoring_enabled, true)
  deployment_host_key   = try(var.n8n.deployment_host_key, "tools")
  dns_zone_override     = try(var.n8n.dns_zone_override, "")
  extra_docker_networks = try(var.n8n.extra_docker_networks, [])
  workflows_dir         = try(var.n8n.workflows_dir, "")

  # Workflow IDs are populated AFTER first import — capture from n8n UI then re-apply.
  extra_env_vars = merge(
    {
      SLACK_CHANNEL_NEW_SIGNUPS        = try(var.n8n.slack_channel_new_signups, "")
      SLACK_CHANNEL_ADMIN_ALERTS       = try(var.n8n.slack_channel_admin_alerts, "")
      BROADSHEET_WORKSPACE_ID          = try(var.n8n.broadsheet_workspace_id, "")
      BROADSHEET_ALL_MEMBERS_LIST_ID   = try(var.n8n.broadsheet_all_members_list_id, "allmembers")
      BROADSHEET_ALL_MEMBERS_LIST_NAME = try(var.n8n.broadsheet_all_members_list_name, "All Members")
      WORKFLOW_ID_BROADSHEET_SUBSCRIBE = try(var.n8n.workflow_id_broadsheet_subscribe, "")
      WORKFLOW_ID_ESPOCRM_UPSERT       = try(var.n8n.workflow_id_espocrm_upsert, "")
      WORKFLOW_ID_SLACK_INVITE_STUB    = try(var.n8n.workflow_id_slack_invite_stub, "")
    },
    module.broadsheet.enabled ? { BROADSHEET_BASE_URL = module.broadsheet.app_url } : {},
    module.espocrm.enabled ? { ESPOCRM_BASE_URL = module.espocrm.app_url } : {},
    try(var.n8n.extra_env_vars, {}),
  )

}

# Backrest — per-host backup service (restic), one instance per compute_host.
# Each instance exposes a forward-auth UI, so it's app-tier (it binds to the
# embedded outpost below). Opt a host out via var.backrest.disabled_hosts.
locals {
  backrest_instances = {
    for k, _ in var.compute_hosts : k => k
    if !contains(try(var.backrest.disabled_hosts, []), k)
  }
}

module "backrest" {
  source   = "../backrest/terraform"
  for_each = local.backrest_instances

  enabled       = true
  instance_name = each.key
  hostname = try(
    var.backrest.per_host[each.key].hostname,
    "backup-${each.key}.${var.base_domain}",
  )
  base = module.base.base

  deployment_host_key = each.key

  authorized_groups = try(
    var.backrest.per_host[each.key].authorized_groups,
    try(var.backrest.authorized_groups, ["admin"]),
  )

  image_tag = try(
    var.backrest.per_host[each.key].image_tag,
    try(var.backrest.image_tag, "latest"),
  )
  storage_class                 = try(var.backrest.storage_class, "GLACIER")
  storage_class_transition_days = try(var.backrest.storage_class_transition_days, 90)
  restic_prune_max_frequency_days = try(
    var.backrest.per_host[each.key].restic_prune_max_frequency_days,
    try(var.backrest.restic_prune_max_frequency_days, 7),
  )
  restic_check_max_frequency_days = try(
    var.backrest.per_host[each.key].restic_check_max_frequency_days,
    try(var.backrest.restic_check_max_frequency_days, 30),
  )
  restic_check_read_data_subset_percent = try(var.backrest.restic_check_read_data_subset_percent, 5)
  backup_sources                        = try(var.backrest.backup_sources, {})

  # Each bundle drops its backup_plan on its host at deploy time and backrest's
  # ansible globs them per-host — so only explicit consumer additions ride
  # through TF here.
  backup_plans = concat(
    try(var.backrest.per_host[each.key].backup_plans, []),
    try(var.backrest.backup_plans, []),
  )

  application_name     = try(var.backrest.application_name, "")
  category_group       = try(var.backrest.category_group, "Technical Management")
  icon_url             = try(var.backrest.icon_url, "")
  icon_filename        = try(var.backrest.icon_filename, "backrest-icon.png")
  monitoring_enabled   = try(var.backrest.monitoring_enabled, true)
  bucket_name_override = try(var.backrest.per_host[each.key].bucket_name_override, "")
  dns_zone_override    = try(var.backrest.dns_zone_override, "")

  extra_env_vars        = try(var.backrest.extra_env_vars, {})
  extra_docker_networks = try(var.backrest.extra_docker_networks, [])
}

# Embedded forward-auth outpost. Forward-auth apps (bentopdf, backrest) register
# their provider IDs here; compact() drops the ones from disabled apps. Authentik
# auto-creates this singleton on first boot, so the consumer's deploy path runs
# `terraform import` on this address before the first apply.
resource "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
  type = "proxy"

  protocol_providers = compact(concat(
    [module.bentopdf.authentik_provider_id],
    [for inst in module.backrest : inst.authentik_provider_id],
  ))

  config = jsonencode({
    authentik_host          = "https://${module.base.base.authentik.identity_domain}/"
    authentik_host_browser  = "https://${module.base.base.authentik.identity_domain}/"
    authentik_host_insecure = false
    log_level               = "info"
    object_naming_template  = "ak-outpost-%(name)s"
    refresh_interval        = "minutes=5"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [service_connection]
  }
}
