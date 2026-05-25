# Bookmark module for Authentik.
#
# A bookmark is an Authentik application with no protocol provider — it
# just shows up in the user portal as a link to an external URL. Used for
# documenting external services that integrate with the Authentik
# identity but don't authenticate through it.

locals {
  # Full URL wins; else compose from icon_base_url + filename; else default-logo.
  effective_icon_url = (
    var.icon_url != "" ? var.icon_url :
    (var.icon_filename != "" && var.icon_base_url != "") ? "${var.icon_base_url}/${var.icon_filename}" :
    "default-logo.png"
  )
}

resource "authentik_application" "bookmark" {
  name              = var.application_name
  slug              = var.application_slug
  protocol_provider = null

  group = var.category_group

  meta_launch_url  = var.launch_url
  meta_description = var.description
  open_in_new_tab  = var.open_in_new_tab
  meta_icon        = local.effective_icon_url

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
