# State-move blocks for in-place upgrades. Each `moved {}` lets terraform
# rename a resource in state without destroying + recreating it. No-op for
# greenfield consumers who never had the old addresses.

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
#
# Backrest moved from a single hand-keyed `backrest_mgmt` module to
# `for_each` over var.compute_hosts. The default shipping block covers the
# "management" instance. Consumers whose forks hand-instantiated additional
# backrest modules (e.g. `backrest_apps`, `backrest_authentik` keyed off
# legacy peer-style instance names) add their own `moved {}` entries in their
# fork pointing those legacy module addresses at the matching
# `module.backrest["<compute_host_key>"]` slot — otherwise terraform will
# destroy the old bucket and recreate a new one, losing snapshots.
#
# If a legacy `instance_name` (e.g. "tools") differs from the new
# compute_hosts key (e.g. "tools-prod"), use
# `var.apps.backrest.per_host["tools-prod"].bucket_name_override = "<old-bucket-name>"`
# to keep the existing bucket attached to the new module address.

moved {
  from = module.backrest_mgmt
  to   = module.backrest["management"]
}

# Backrest instance-key renames that ride on the canonical host-key rename
# above. Consumers who upgraded TO v3.4.0 with the new for_each shape on the
# old "apps"/"authentik" keys (which would only happen if they applied a
# beta v3.4 against pre-rename compute_hosts) get these. Harmless no-op for
# anyone landing v3.4.0 cleanly.
moved {
  from = module.backrest["apps"]
  to   = module.backrest["tools"]
}

moved {
  from = module.backrest["authentik"]
  to   = module.backrest["identity"]
}
