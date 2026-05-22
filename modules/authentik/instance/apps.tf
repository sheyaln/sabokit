module "outline" {
  source = "../oidc-app"

  application_name = "Wiki - Outline"
  application_slug = "outline"

  redirect_uris = [
    {
      url = "https://wiki.${var.domain}/auth/oidc.callback"
    }
  ]
  access_level = "member"

  category_group = "Member Resources"

  oidc_scopes           = ["openid", "profile", "email", "groups", "offline_access"]
  access_token_validity = "hours=1"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "outline-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

# Grafana monitoring application (delegates get Editor, admins get Admin)
module "grafana" {
  source = "../oidc-app"

  application_name = "Grafana"
  application_slug = "grafana"
  category_group   = "Technical Management"

  redirect_uris = [
    {
      url = "https://grafana.${var.mgmt_domain}/login/generic_oauth"
    }
  ]
  access_level = "delegate"

  oidc_scopes = ["openid", "profile", "email", "groups", "offline_access"]

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "grafana-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

# Zabbix Monitoring - SAML Authentication
# Zabbix uses php-saml library for SAML2 SSO
module "zabbix" {
  source = "../saml-app"

  application_name = "Zabbix"
  application_slug = "zabbix"
  launch_url       = "https://zabbix.${var.mgmt_domain}"
  category_group   = "Technical Management"

  # ACS URL is the endpoint where Authentik posts the SAML assertion
  saml_assertion_consumer_service_url = "https://zabbix.${var.mgmt_domain}/index_sso.php?acs"

  # Audience/Entity ID must match what's configured in Zabbix SAML settings
  saml_audience = "zabbix"

  saml_service_provider_binding = "post"
  saml_sign_assertion           = true
  saml_digest_algorithm         = "http://www.w3.org/2001/04/xmlenc#sha256"
  saml_signature_algorithm      = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"

  saml_name_id_use_email = true

  generate_rsa_signing_key = true
  gateway_domain           = var.gateway_domain
  org_name                 = var.org_name

  access_level = "admin"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "zabbix-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

# Nextcloud / Cloud Storage
# Note: App name and icon can be customized via project.yml or override in apps_local.tf
module "nextcloud" {
  source = "../oidc-app"

  application_name = "Sabo Cloud"
  application_slug = "sabo-cloud"
  launch_url       = "https://cloud.${var.domain}/apps/user_oidc/login/3"

  redirect_uris = [
    {
      url           = "https://cloud.${var.domain}/apps/user_oidc/code"
      matching_mode = "strict"
    }
  ]
  access_level = "member"

  generate_rsa_signing_key = true
  gateway_domain           = var.gateway_domain
  org_name                 = var.org_name

  oidc_scopes = ["openid", "profile", "email", "groups"]

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "sabo-cloud-icon.png"
  sub_mode = "user_id"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }
}

module "espocrm" {
  source = "../oidc-app"

  application_name = "EspoCRM"
  application_slug = "espocrm"
  launch_url       = "https://espo.${var.domain}"

  redirect_uris = [
    {
      url           = "https://espo.${var.domain}/oauth-callback.php"
      matching_mode = "strict"
    }
  ]

  access_level = "delegate"

  oidc_scopes = ["openid", "profile", "email", "groups"]

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "espocrm-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }
}

# n8n Workflow Automation - OIDC Authentication
module "n8n" {
  source = "../oidc-app"

  application_name = "n8n Automation"
  application_slug = "n8n"
  launch_url       = "https://n8n.${var.mgmt_domain}"
  category_group   = "Technical Management"

  redirect_uris = [
    {
      url           = "https://n8n.${var.mgmt_domain}/auth/oidc/callback"
      matching_mode = "strict"
    }
  ]

  oidc_scopes = ["openid", "email", "profile"]

  access_level = "delegate"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "n8n-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

module "vikunja" {
  source = "../oidc-app"

  application_name = "Vikunja Tasks"
  application_slug = "vikunja"
  category_group   = "Member Tools"

  redirect_uris = [
    {
      url           = "https://tasks.${var.domain}/auth/openid/authentik"
      matching_mode = "strict"
    }
  ]

  # vikunja_scope provides the vikunja_groups claim for automatic team assignment
  oidc_scopes           = ["openid", "email", "profile", "vikunja_scope"]
  access_token_validity = "hours=1"

  vikunja_team_name = var.org_name

  access_level = "member"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "vikunja-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

# Jitsi Meet - OIDC Authentication via custom adapter
# Uses a Flask-based OIDC adapter that handles the auth flow and issues JWTs
# The adapter sits at /oidc on the same domain as Jitsi
module "jitsi" {
  source = "../oidc-app"

  application_name = "Jitsi Meet"
  application_slug = "jitsi"
  launch_url       = "https://meet.${var.domain}"

  redirect_uris = concat(
    [{
      url           = "https://meet.${var.domain}/oidc/redirect"
      matching_mode = "strict"
    }],
    [for url in lookup(var.extra_redirect_uris, "jitsi", []) : {
      url           = url
      matching_mode = "strict"
    }]
  )

  access_level = "member"

  oidc_scopes = ["openid", "email", "profile"]

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "jitsi-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

# DEPRECATED: Script Server (replaced by n8n, May 2026)
# To remove from Authentik: terraform destroy -target=module.script-server
# module "script-server" {
#   source = "../oidc-app"
#
#   application_name = "Script Server"
#   application_slug = "script-server"
#   launch_url       = "https://script-server.${var.mgmt_domain}"
#   category_group   = "Technical Management"
#
#   redirect_uris = [
#     {
#       url = "https://script-server.${var.mgmt_domain}/login.html"
#     }
#   ]
#   access_level = "delegate"
#
#   oidc_scopes = ["openid", "profile", "email", "groups"]
#
#   authentication_flow_uuid = module.flows.authentication_flow_login
#   authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
#   invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id
#
#   icon_url = "script-server-icon.png"
#
#   group_ids = {
#     admin           = authentik_group.admin.id
#     union_delegate  = authentik_group.union_delegate.id
#     union_member    = authentik_group.union_member.id
#     union_treasurer = authentik_group.union_treasurer.id
#   }
#
#   depends_on = [
#     authentik_group.admin,
#     authentik_group.union_delegate,
#     authentik_group.union_member,
#     authentik_group.union_treasurer
#   ]
# }

# Notifuse Newsletter Platform - OIDC Authentication
module "notifuse" {
  source = "../oidc-app"

  application_name = "Notifuse"
  application_slug = "notifuse"
  launch_url       = "https://email.campaigns.${var.domain}"
  category_group   = "Member Tools"

  redirect_uris = [
    {
      url           = "https://email.campaigns.${var.domain}/api/auth/oidc/callback"
      matching_mode = "strict"
    }
  ]

  access_level = "delegate"

  oidc_scopes = ["openid", "email", "profile", "groups"]

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "notifuse-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

# -----------------------------------------------------------------------------
# FORWARD AUTH APPS (SSO-protected, no native OIDC/SAML)
# -----------------------------------------------------------------------------
# These apps use Authentik's forward auth proxy via Traefik middleware.
# The app itself has no OIDC support; Traefik handles authentication.
# Essentially, Traefik, the proxy that routes connections to the application, will refuse
# to route the connection to the application unless the user is authenticated with Authentik 
# and has the necessary permissions.

# Per-host Backrest backup UIs — one instance per production server.
# Each server runs its own Backrest for local backup to a dedicated S3 bucket.
module "backrest_mgmt" {
  source = "../traefik-forward-auth"

  application_name = "Backrest (Management)"
  application_slug = "backrest-mgmt"
  external_host    = "https://backup.mgmt.prod.${var.mgmt_domain}"
  category_group   = "Technical Management"
  access_level     = "admin"

  icon_url = "backrest-icon.png"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

module "backrest_tools" {
  source = "../traefik-forward-auth"

  application_name = "Backrest (Tools)"
  application_slug = "backrest-tools"
  external_host    = "https://backup.tools.prod.${var.mgmt_domain}"
  category_group   = "Technical Management"
  access_level     = "admin"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "backrest-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

module "backrest_gateway" {
  source = "../traefik-forward-auth"

  application_name = "Backrest (Gateway)"
  application_slug = "backrest-gateway"
  external_host    = "https://backup.gateway.prod.${var.mgmt_domain}"
  category_group   = "Technical Management"
  access_level     = "admin"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "backrest-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

# Wazuh SIEM Dashboard - SAML Authentication
# Wazuh uses OpenSearch Dashboards which requires SAML for SSO
module "wazuh" {
  source = "../saml-app"

  application_name = "Wazuh SIEM"
  application_slug = "wazuh"
  launch_url       = "https://wazuh.${var.mgmt_domain}"
  category_group   = "Technical Management"

  # ACS URL is the endpoint where Authentik posts the SAML assertion
  saml_assertion_consumer_service_url = "https://wazuh.${var.mgmt_domain}/_opendistro/_security/saml/acs"

  # Audience/Entity ID must match what's configured in Wazuh indexer config.yml
  saml_audience = "wazuh-saml"

  saml_service_provider_binding = "post"
  saml_sign_assertion           = true
  saml_digest_algorithm         = "http://www.w3.org/2001/04/xmlenc#sha256"
  saml_signature_algorithm      = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"

  saml_name_id_use_email = true

  include_groups_attribute = true

  generate_rsa_signing_key = true
  gateway_domain           = var.gateway_domain
  org_name                 = var.org_name

  access_level = "admin"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  icon_url = "wazuh-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}

# BentoPDF -- client-side PDF toolbox (Ansible role: tools/bentopdf).
# Forward-auth protected; available to all members.
module "bentopdf" {
  source = "../traefik-forward-auth"

  application_name = "BentoPDF"
  application_slug = "bentopdf"
  external_host    = "https://pdf.${var.domain}"
  category_group   = "Member Tools"
  access_level     = "member"

  authentication_flow_uuid = module.flows.authentication_flow_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_provider_invalidation_flow_id

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }

  depends_on = [
    authentik_group.admin,
    authentik_group.union_delegate,
    authentik_group.union_member,
    authentik_group.union_treasurer
  ]
}


