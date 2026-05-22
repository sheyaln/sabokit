terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
  }
}

# Data-driven DNS record provisioning. Consumers load their records spec from
# wherever (YAML, JSON, inline locals) and pass it as structured data; this
# module flattens it into per-record resources.
#
# Records whose domain_key isn't in `domain_zones` are silently dropped — lets
# consumers conditionally provision zones (e.g. staging zone exists only when
# staging_domain != tools_domain). Same for A records whose server isn't in
# `server_ips` — covers "staging IP not known yet" cases without forcing a
# split apply.

locals {
  app_a_records = {
    for record in flatten([
      for domain_key, records in var.dns_records : [
        for r in records : merge(r, {
          domain_key = domain_key
          unique_key = "${domain_key}_${replace(r.subdomain, "*", "wildcard")}"
        }) if r.type == "A"
        && lookup(var.domain_zones, domain_key, null) != null
        && lookup(var.server_ips, r.server, null) != null
      ]
    ]) : record.unique_key => record
  }

  app_cname_records = {
    for record in flatten([
      for domain_key, records in var.dns_records : [
        for r in records : merge(r, {
          domain_key = domain_key
          unique_key = "${domain_key}_${r.subdomain}"
        }) if r.type == "CNAME"
        && lookup(var.domain_zones, domain_key, null) != null
      ]
    ]) : record.unique_key => record
  }
}

resource "scaleway_domain_record" "app_a" {
  for_each = local.app_a_records

  dns_zone = var.domain_zones[each.value.domain_key]
  name     = each.value.subdomain
  type     = "A"
  data     = var.server_ips[each.value.server]
  ttl      = each.value.ttl

  lifecycle {
    prevent_destroy = true
  }
}

resource "scaleway_domain_record" "app_cname" {
  for_each = local.app_cname_records

  dns_zone = var.domain_zones[each.value.domain_key]
  name     = each.value.subdomain
  type     = "CNAME"
  data     = each.value.target
  ttl      = each.value.ttl

  lifecycle {
    prevent_destroy = true
  }
}
