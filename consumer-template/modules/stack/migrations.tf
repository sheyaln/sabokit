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

# ── Backrest per-host fan-out (v3.4.0) ───────────────────────────────────

moved {
  from = module.backrest_mgmt
  to   = module.backrest["management"]
}

moved {
  from = module.backrest["apps"]
  to   = module.backrest["tools"]
}

moved {
  from = module.backrest["authentik"]
  to   = module.backrest["identity"]
}

# ── Diun → host-services tier (v3.4.0) ───────────────────────────────────
# Zero TF resources in diun bundle, no moved{} needed. Consumers remove
# `var.apps.diun_mgmt` from tfvars and configure `var.base.diun.*` instead.

# ── Autoheal → host-services tier (v3.4.0) ───────────────────────────────

moved {
  from = module.autoheal_apps
  to   = module.base.module.autoheal["tools"]
}

moved {
  from = module.base.module.autoheal["apps"]
  to   = module.base.module.autoheal["tools"]
}

moved {
  from = module.base.module.autoheal["authentik"]
  to   = module.base.module.autoheal["identity"]
}

# ── Wazuh-agent → host-services tier (v3.4.0) ────────────────────────────

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
