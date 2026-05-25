# A record for the app hostname → the deployment host's public IP.
# We use scaleway_domain_record directly (not the app_dns module) because we
# need exactly one A record per app, not a data-driven sweep.
#
# Zone is derived from var.hostname via longest-suffix match against
# var.base.domains.zones (split-domain support). var.dns_zone_override pins
# it manually for edge cases.

locals {
  _dns_matching_zones = [
    for z in var.base.domains.zones :
    z if endswith(var.hostname, ".${z}") || var.hostname == z
  ]
  _dns_longest_match = length(local._dns_matching_zones) == 0 ? "" : reverse(sort([
    for z in local._dns_matching_zones : format("%03d:%s", length(z), z)
  ]))[0]
  dns_zone        = var.dns_zone_override != "" ? var.dns_zone_override : (length(local._dns_matching_zones) == 0 ? "" : split(":", local._dns_longest_match)[1])
  dns_record_name = var.hostname == local.dns_zone ? "@" : trimsuffix(var.hostname, ".${local.dns_zone}")
}

resource "scaleway_domain_record" "this" {
  count = var.enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.dns_zone != ""
      error_message = "var.hostname (${var.hostname}) doesn't end in any zone listed in var.base.domains.zones (${jsonencode(var.base.domains.zones)}). Add the parent zone to base.domains (e.g. set var.mgmt_domain at the base layer) or set var.dns_zone_override explicitly."
    }
  }

  dns_zone = local.dns_zone
  name     = local.dns_record_name
  type     = "A"
  data     = var.base.compute.hosts[var.deployment_host_key].public_ip
  ttl      = 300
}
