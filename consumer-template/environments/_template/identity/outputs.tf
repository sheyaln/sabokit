# Downstream layers (operations/application) rediscover Authentik by name via
# the data-source contract, not via this output — it's surfaced for debugging
# and to confirm the tier groups + flows landed.

output "authentik" {
  description = "Authentik contract object: flows, group_name -> id map, sources."
  value       = module.identity.authentik
}
