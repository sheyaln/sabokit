locals {
  name_suffix = "${var.org_slug}-${var.environment}"

  base_tags = concat(var.tags, [var.environment, "managed-by:sabokit"])

  mgmt_domain    = var.mgmt_domain != null ? var.mgmt_domain : var.base_domain
  gateway_domain = var.gateway_domain != null ? var.gateway_domain : "auth.${var.base_domain}"

  postgres_instance_name = "${local.name_suffix}-postgres"
  postgres_admin_user    = "${var.org_slug}-admin"
}
