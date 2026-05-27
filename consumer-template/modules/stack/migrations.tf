# State migrations for the host-services tier introduction (v3.4.0). The
# autoheal bundle moved from platform/apps/ into platform/base/host-services/
# and the per-host instance is now produced by a for_each in the base layer
# rather than a hand-written module call per host in this stack.
#
# Existing consumers' state has `module.autoheal_apps`; new state has
# `module.base.autoheal["tools"]` (canonical 3-host key). Each moved{} below
# replaces the manual terraform-state-mv step that would otherwise be required
# on the v3.3 → v3.4 bump. The "authentik"/"identity" + "management" entries
# cover consumers who pre-instantiated autoheal on those hosts.

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
