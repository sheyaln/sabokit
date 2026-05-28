# State-move blocks for in-place upgrades. Each `moved {}` lets terraform
# rename a resource in state without destroying + recreating it. No-op for
# greenfield consumers who never had the old addresses.
#
# Drop entries after consumers have applied past the tag that introduced them
# — 2 minor versions is the conventional grace.

# ── Canonical 3-host rename (v3.4.0) ─────────────────────────────────────
#
# Upstream consumer-template default flipped from single-host {apps} to
# 3-host {tools, identity, management}. Consumers using the prior key names
# move their state via these blocks. Apps-host and authentik-host renames
# only — "management" was already canon.

moved {
  from = module.base.module.compute_host["apps"]
  to   = module.base.module.compute_host["tools"]
}

moved {
  from = module.base.module.compute_host["authentik"]
  to   = module.base.module.compute_host["identity"]
}


# ── Diun → host-services tier (v3.4.0) ───────────────────────────────────
# Zero TF resources in diun bundle, no moved{} needed. Consumers remove
# `var.apps.diun_mgmt` from tfvars and configure `var.base.diun.*` instead.

# ── Autoheal → host-services tier (v3.4.0) ───────────────────────────────
# Single move from the v3.3.x apps-tier address to the canonical "tools" key
# under the new for_each. Forks with additional per-host autoheal instances
# (e.g. `autoheal_management`, `autoheal_authentik`) add their own moved{}
# blocks in their fork-local migrations.tf — upstream can't cover every
# fork's pre-v3.4 instance set.

moved {
  from = module.autoheal_apps
  to   = module.base.module.autoheal["tools"]
}

moved {
  from = module.base.module.autoheal["authentik"]
  to   = module.base.module.autoheal["identity"]
}

# ── Wazuh-agent → host-services tier (v3.4.0) ────────────────────────────
# Same shape as autoheal above.

moved {
  from = module.wazuh_agent_apps
  to   = module.base.module.wazuh_agent["tools"]
}

moved {
  from = module.base.module.wazuh_agent["authentik"]
  to   = module.base.module.wazuh_agent["identity"]
}

# ── Core tier relocation (v3.4.0) ────────────────────────────────────────
# loki / prometheus / grafana / wazuh manager moved from platform/apps/ to
# platform/core/ and compose under a single module.core block.

moved {
  from = module.loki
  to   = module.core.module.loki
}

moved {
  from = module.prometheus
  to   = module.core.module.prometheus
}

moved {
  from = module.grafana
  to   = module.core.module.grafana
}

moved {
  from = module.wazuh
  to   = module.core.module.wazuh
}
