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
# staging_domain != tools_domain). Same for A/AAAA records whose server isn't
# in `server_ips` — covers "staging IP not known yet" cases without forcing a
# split apply.
#
# Supported types: A, AAAA (server-keyed via server_ips), CNAME, MX, TXT, SRV
# (target-keyed; pass the literal Scaleway `data` field in `target`).

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

  app_aaaa_records = {
    for record in flatten([
      for domain_key, records in var.dns_records : [
        for r in records : merge(r, {
          domain_key = domain_key
          unique_key = "${domain_key}_${replace(r.subdomain, "*", "wildcard")}"
        }) if r.type == "AAAA"
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

  # MX/TXT/SRV can have multiple records at the same name (e.g. two MX with
  # different priorities, multiple TXT verifications). Include the target in
  # the unique_key so they don't collide.
  app_mx_records = {
    for record in flatten([
      for domain_key, records in var.dns_records : [
        for r in records : merge(r, {
          domain_key = domain_key
          unique_key = "${domain_key}_${r.subdomain}_${r.target}"
        }) if r.type == "MX"
        && lookup(var.domain_zones, domain_key, null) != null
      ]
    ]) : record.unique_key => record
  }

  app_txt_records = {
    for record in flatten([
      for domain_key, records in var.dns_records : [
        for r in records : merge(r, {
          domain_key = domain_key
          unique_key = "${domain_key}_${r.subdomain}_${substr(sha256(r.target), 0, 8)}"
        }) if r.type == "TXT"
        && lookup(var.domain_zones, domain_key, null) != null
      ]
    ]) : record.unique_key => record
  }

  app_srv_records = {
    for record in flatten([
      for domain_key, records in var.dns_records : [
        for r in records : merge(r, {
          domain_key = domain_key
          unique_key = "${domain_key}_${r.subdomain}_${substr(sha256(r.target), 0, 8)}"
        }) if r.type == "SRV"
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

resource "scaleway_domain_record" "app_aaaa" {
  for_each = local.app_aaaa_records

  dns_zone = var.domain_zones[each.value.domain_key]
  name     = each.value.subdomain
  type     = "AAAA"
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

# MX: `data` is "<priority> <target>" (e.g. "10 mail.protonmail.ch.").
resource "scaleway_domain_record" "app_mx" {
  for_each = local.app_mx_records

  dns_zone = var.domain_zones[each.value.domain_key]
  name     = each.value.subdomain
  type     = "MX"
  # MX target is "<priority> <host.>" (per the var docs, e.g. "10 mail.x.com.").
  # Scaleway keeps the priority in its own `priority` field, not in `data` —
  # putting the whole "10 mail.x.com." in data serves a broken "10 10 mail.x.com.".
  # Split so priority and the mail host land in the right fields.
  priority = tonumber(split(" ", each.value.target)[0])
  data     = trimprefix(each.value.target, "${split(" ", each.value.target)[0]} ")
  ttl      = each.value.ttl

  lifecycle {
    prevent_destroy = true
  }
}

# TXT: `data` is the literal string. Scaleway wraps in quotes as needed.
resource "scaleway_domain_record" "app_txt" {
  for_each = local.app_txt_records

  dns_zone = var.domain_zones[each.value.domain_key]
  name     = each.value.subdomain
  type     = "TXT"
  data     = each.value.target
  ttl      = each.value.ttl

  lifecycle {
    prevent_destroy = true
  }
}

# SRV: `data` is "<priority> <weight> <port> <target>".
resource "scaleway_domain_record" "app_srv" {
  for_each = local.app_srv_records

  dns_zone = var.domain_zones[each.value.domain_key]
  name     = each.value.subdomain
  type     = "SRV"
  data     = each.value.target
  ttl      = each.value.ttl

  lifecycle {
    prevent_destroy = true
  }
}
