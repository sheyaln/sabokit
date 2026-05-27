# State address migrations. Keeps `terraform plan` clean across sabokit
# version bumps when modules are renamed, moved, or restructured.

# v3.4.0 — wazuh-agent moved from platform/apps/ to platform/base/host-services/
# and auto-instantiates per compute_host inside module.base. The example
# template previously declared a single instance keyed by "apps".
# Consumers with additional wazuh-agent instances (e.g. _management,
# _authentik) must add their own `moved {}` blocks alongside this one,
# matching the key they used in module.base.compute.hosts.
moved {
  from = module.wazuh_agent_apps
  to   = module.base.module.wazuh_agent["apps"]
}
