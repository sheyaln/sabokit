# Bookmark module for Authentik.
#
# A bookmark is an Authentik application with no protocol provider — it
# just shows up in the user portal as a link to an external URL. Used for
# documenting external services that integrate with the Authentik
# identity but don't authenticate through it.

resource "authentik_application" "bookmark" {
  name              = var.application_name
  slug              = var.application_slug
  protocol_provider = null

  group = var.category_group

  meta_launch_url  = var.launch_url
  meta_description = var.description
  open_in_new_tab  = var.open_in_new_tab
  meta_icon        = var.icon_url != null ? var.icon_url : "default-logo.png"

  policy_engine_mode = "any"

  lifecycle {
    ignore_changes = [
      meta_icon,
    ]
  }
}

resource "authentik_policy_binding" "authorized" {
  for_each = var.authorized_groups

  target = authentik_application.bookmark.uuid
  group  = each.value
  # Authentik's API enforces uniqueness on (policy, target, order) for UPDATE.
  # A hardcoded order=10 across all bindings means the 2nd binding onward
  # fails with HTTP 400 — and you can't reverse out of a partial apply
  # because the pre-check rejects both directions. Stagger via lex-ordered
  # key index so each binding lands in a distinct slot.
  order = 10 + index(keys(var.authorized_groups), each.key)
}
