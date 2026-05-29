terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
  }
}

resource "scaleway_instance_security_group" "this" {
  name        = var.name
  description = var.description

  enable_default_security = var.enable_default_security
  external_rules          = null
  inbound_default_policy  = var.inbound_default_policy
  outbound_default_policy = var.outbound_default_policy
  stateful                = var.stateful

  dynamic "inbound_rule" {
    for_each = var.inbound_rules
    content {
      action     = "accept"
      ip_range   = inbound_rule.value.ip_range
      protocol   = inbound_rule.value.protocol
      port       = inbound_rule.value.port
      port_range = inbound_rule.value.port_range
    }
  }
}
