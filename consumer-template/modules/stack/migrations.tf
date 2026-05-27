# State-address migrations for cross-tier moves. Each `moved` block lets
# `terraform plan` re-key existing state into the new module address with
# zero resource churn. Drop entries after consumers have applied past the
# tag that introduced them — 2 minor versions is the conventional grace.

# v3.4.0: diun moved from platform/apps/diun to platform/base/host-services/diun,
# auto-instantiated per compute_host from the base tier. No `moved` block
# is emitted because the diun bundle is a contract-only compute module with
# zero `resource` declarations — terraform tracks no state under
# `module.diun_mgmt`, so the address simply disappears on apply with no
# downstream effect. Consumers who previously enabled `var.apps.diun_mgmt`
# should remove that key from tfvars and configure `var.base.diun.*` instead.
