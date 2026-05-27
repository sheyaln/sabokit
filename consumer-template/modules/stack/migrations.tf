# State address migrations. Keeps `terraform plan` clean across sabokit
# version bumps when modules are renamed, moved, or restructured.

# v3.4.0 — wazuh-agent moved from platform/apps/ to platform/base/host-services/
# and auto-instantiates per compute_host inside module.base. Canonical 3-host
# naming landed in the same release, so the legacy "apps" host key now lives
# under "tools" and the legacy "authentik" identity host under "identity".
moved {
  from = module.wazuh_agent_apps
  to   = module.base.module.wazuh_agent["tools"]
}

moved {
  from = module.base.module.wazuh_agent["apps"]
  to   = module.base.module.wazuh_agent["tools"]
}

moved {
  from = module.base.module.wazuh_agent["authentik"]
  to   = module.base.module.wazuh_agent["identity"]
}
