# One module call per app. All gated by var.apps.<name>.enabled (default false).
# Uncomment / enable in terraform.tfvars to turn an app on.

module "outline" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/apps/outline/terraform?ref=v1.0.0"

  enabled  = try(var.apps.outline.enabled, false)
  hostname = try(var.apps.outline.hostname, "")
  base     = local.base

  # Optional overrides
  access_level            = try(var.apps.outline.access_level, "member")
  extra_authorized_groups = try(var.apps.outline.extra_authorized_groups, [])
  smtp_from_email         = try(var.apps.outline.smtp_from_email, "")
  monitoring_enabled      = try(var.apps.outline.monitoring_enabled, true)
  deployment_host_key     = try(var.apps.outline.deployment_host_key, "apps")
}

# Add more apps here as bundles ship. Same shape every time:
#
# module "nextcloud" {
#   source   = "git::https://github.com/sheyaln/sabokit.git//platform/apps/nextcloud/terraform?ref=v1.0.0"
#   enabled  = try(var.apps.nextcloud.enabled, false)
#   hostname = try(var.apps.nextcloud.hostname, "")
#   base     = local.base
# }
