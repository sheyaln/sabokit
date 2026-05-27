locals {
  slug = "diun"

  # Per-instance name suffix; mirrors the backrest multi-instance pattern.
  # Empty default = single-instance consumers don't have to name it.
  qualified_slug = var.instance_name == "" ? local.slug : "${local.slug}-${var.instance_name}"
}
