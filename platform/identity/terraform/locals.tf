locals {
  # Resolved SMTP From display name. When the consumer doesn't set from_name
  # explicitly we fall back to the org's display name.
  from_name = var.from_name != "" ? var.from_name : var.org_name

  # JSON-encoded list of group names that should receive user-lifecycle email
  # notifications. Always includes admin; includes delegate when that tier is
  # enabled. The expressions Python templates parse this as a Python literal.
  notification_target_groups_json = jsonencode(
    var.delegate_group_name != null
    ? [var.admin_group_name, var.delegate_group_name]
    : [var.admin_group_name]
  )

  # Test mode collapses recipients to admins only.
  notification_test_target_groups_json = jsonencode([var.admin_group_name])

  # Empty icon_base_url resolves to the pinned sabokit-assets default so
  # consumers can pass `try(var.identity.icon_base_url, "")` straight through
  # without hardcoding the upstream URL on every fork.
  effective_icon_base_url = var.icon_base_url != "" ? var.icon_base_url : "https://raw.githubusercontent.com/sheyaln/sabokit-assets/v1.0.0/application-icons"
}
