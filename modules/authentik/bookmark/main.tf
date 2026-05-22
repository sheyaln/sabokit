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
  for_each = toset(var.authorized_group_ids)

  target = authentik_application.bookmark.uuid
  group  = each.value
  order  = 10
}
