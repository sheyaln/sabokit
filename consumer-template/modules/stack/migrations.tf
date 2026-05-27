# State-move blocks for in-place upgrades. Each `moved {}` lets terraform
# rename a resource in state without destroying + recreating it.
#
# v3.4.0: backrest moved from a single hand-keyed `backrest_mgmt` module to
# `for_each` over var.compute_hosts. Default ships with one `moved {}` block
# for the "management" key. Consumers whose forks hand-instantiated additional
# backrest modules (e.g. `backrest_apps`, `backrest_authentik` keyed off
# legacy peer-style instance names) MUST add their own `moved {}` entries
# here pointing those legacy module addresses at the matching
# `module.backrest["<compute_host_key>"]` slot — otherwise terraform will
# destroy the old bucket and recreate a new one, losing snapshots.
#
# If your legacy `instance_name` (e.g. "tools") differs from the new
# compute_hosts key (e.g. "tools-prod"), use
# `var.apps.backrest.per_host["tools-prod"].bucket_name_override = "<old-bucket-name>"`
# to keep the existing bucket attached to the new module address.

moved {
  from = module.backrest_mgmt
  to   = module.backrest["management"]
}
