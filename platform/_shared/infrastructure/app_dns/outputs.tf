output "a_record_ids" {
  description = "Map of unique_key to A record ID. Keys are formatted as domain_key + underscore + subdomain (with asterisks replaced by 'wildcard')."
  value       = { for k, v in scaleway_domain_record.app_a : k => v.id }
}

output "cname_record_ids" {
  description = "Map of unique_key to CNAME record ID."
  value       = { for k, v in scaleway_domain_record.app_cname : k => v.id }
}
