# Per-hostname zone derivation. Each of the three A records (nextcloud,
# onlyoffice, talk) consults its own hostname against var.base.domains.zones
# by longest-suffix match (split-domain support). var.dns_zone_override pins
# the zone for all three uniformly when set; per-hostname override would need
# a richer schema and isn't justified by any known use case.

locals {
  _nc_dns_matching_zones = [
    for z in var.base.domains.zones :
    z if endswith(var.hostname, ".${z}") || var.hostname == z
  ]
  _nc_dns_longest_match = length(local._nc_dns_matching_zones) == 0 ? "" : reverse(sort([
    for z in local._nc_dns_matching_zones : format("%03d:%s", length(z), z)
  ]))[0]
  nc_dns_zone        = var.dns_zone_override != "" ? var.dns_zone_override : (length(local._nc_dns_matching_zones) == 0 ? "" : split(":", local._nc_dns_longest_match)[1])
  nc_dns_record_name = var.hostname == local.nc_dns_zone ? "@" : trimsuffix(var.hostname, ".${local.nc_dns_zone}")

  _oo_dns_matching_zones = [
    for z in var.base.domains.zones :
    z if endswith(var.onlyoffice_hostname, ".${z}") || var.onlyoffice_hostname == z
  ]
  _oo_dns_longest_match = length(local._oo_dns_matching_zones) == 0 ? "" : reverse(sort([
    for z in local._oo_dns_matching_zones : format("%03d:%s", length(z), z)
  ]))[0]
  oo_dns_zone        = var.dns_zone_override != "" ? var.dns_zone_override : (length(local._oo_dns_matching_zones) == 0 ? "" : split(":", local._oo_dns_longest_match)[1])
  oo_dns_record_name = var.onlyoffice_hostname == local.oo_dns_zone ? "@" : trimsuffix(var.onlyoffice_hostname, ".${local.oo_dns_zone}")

  _talk_dns_matching_zones = [
    for z in var.base.domains.zones :
    z if endswith(var.talk_hostname, ".${z}") || var.talk_hostname == z
  ]
  _talk_dns_longest_match = length(local._talk_dns_matching_zones) == 0 ? "" : reverse(sort([
    for z in local._talk_dns_matching_zones : format("%03d:%s", length(z), z)
  ]))[0]
  talk_dns_zone        = var.dns_zone_override != "" ? var.dns_zone_override : (length(local._talk_dns_matching_zones) == 0 ? "" : split(":", local._talk_dns_longest_match)[1])
  talk_dns_record_name = var.talk_hostname == local.talk_dns_zone ? "@" : trimsuffix(var.talk_hostname, ".${local.talk_dns_zone}")
}

resource "scaleway_domain_record" "this" {
  count = var.enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.nc_dns_zone != ""
      error_message = "var.hostname (${var.hostname}) doesn't end in any zone listed in var.base.domains.zones (${jsonencode(var.base.domains.zones)}). Add the parent zone to base.domains (e.g. set var.mgmt_domain at the base layer) or set var.dns_zone_override explicitly."
    }
  }

  dns_zone = local.nc_dns_zone
  name     = local.nc_dns_record_name
  type     = "A"
  data     = var.base.compute.hosts[var.deployment_host_key].public_ip
  ttl      = 3600
}

# OnlyOffice runs on the same host as Nextcloud, but the browser loads the
# editor IFrame from this hostname directly — Traefik routes it to the
# documentserver container.
resource "scaleway_domain_record" "onlyoffice" {
  count = var.enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.oo_dns_zone != ""
      error_message = "var.onlyoffice_hostname (${var.onlyoffice_hostname}) doesn't end in any zone listed in var.base.domains.zones (${jsonencode(var.base.domains.zones)}). Add the parent zone to base.domains (e.g. set var.mgmt_domain at the base layer) or set var.dns_zone_override explicitly."
    }
  }

  dns_zone = local.oo_dns_zone
  name     = local.oo_dns_record_name
  type     = "A"
  data     = var.base.compute.hosts[var.deployment_host_key].public_ip
  ttl      = 3600
}

# Talk HPB. Same A record covers two things: HTTPS WSS signaling routed via
# Traefik AND the eturnal TURN server on UDP/TCP 3478 bound directly to the
# host. Keep both on one hostname so clients only ever resolve one name.
resource "scaleway_domain_record" "talk" {
  count = var.enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.talk_dns_zone != ""
      error_message = "var.talk_hostname (${var.talk_hostname}) doesn't end in any zone listed in var.base.domains.zones (${jsonencode(var.base.domains.zones)}). Add the parent zone to base.domains (e.g. set var.mgmt_domain at the base layer) or set var.dns_zone_override explicitly."
    }
  }

  dns_zone = local.talk_dns_zone
  name     = local.talk_dns_record_name
  type     = "A"
  data     = var.base.compute.hosts[var.deployment_host_key].public_ip
  ttl      = 3600
}
