# Default security group applied to compute hosts that don't override it.
# Allows SSH/HTTP/HTTPS from anywhere and any extra rules the consumer adds.
# Apps that need their own ingress (e.g. Jitsi TURN/STUN) define a separate
# security group in their bundle and pass its ID via compute_hosts[*].security_group_id.

module "default_security_rules" {
  source = "../../../modules/infrastructure/common_security_rules"

  enable_ssh   = true
  enable_http  = true
  enable_https = true
}

module "default_security_group" {
  source = "../../../modules/infrastructure/security_group"

  name        = "${local.name_suffix}-default"
  description = "Default SG for ${var.org_slug} ${var.environment}: SSH/HTTP/HTTPS + consumer extras"

  inbound_rules = concat(
    module.default_security_rules.inbound_rules,
    var.default_security_group_extra_inbound_rules,
  )
}
