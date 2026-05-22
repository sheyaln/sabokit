output "a_record_ids" {
  description = "Map of unique_key → A record ID. Keyed by `${domain_key}_${subdomain}` (with `*` replaced by `wildcard`)."
  value       = { for k, v in scaleway_domain_record.app_a : k => v.id }
}

output "cname_record_ids" {
  description = "Map of unique_key → CNAME record ID."
  value       = { for k, v in scaleway_domain_record.app_cname : k => v.id }
}
