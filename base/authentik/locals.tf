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
}
