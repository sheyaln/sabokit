# Gateway DNS A record. Created in the SAME terraform apply that provisions
# the identity host's compute instance, so DNS is correct by the time Traefik
# requests the Let's Encrypt cert. Drops the deploy-time `scw dns record set`
# shim that used to live in consumer-template's up.sh.
#
# Cross-project: most consumers have everything in one Scaleway project, so
# the default `scaleway.dns` provider alias points at the same credentials
# as `scaleway`. Operators whose DNS zone lives in a different project
# override the alias in their per-env providers.tf with separate creds.
#
# Identity-host selection (which host's public IP the record points at):
#   1. var.gateway_compute_host_key — explicit override (multi-host prod
#      typically sets this to whichever host runs Authentik).
#   2. First host with "identity" in its ansible_groups list (single-VM
#      staging usually has one VM in both [apps] and [identity]).
#   3. First host with role = "identity".
#   4. First compute host (lexicographic by key) — last-resort fallback.
locals {
  gateway_host_key = coalesce(
    var.gateway_compute_host_key,
    try([for k, h in var.compute_hosts : k if contains(coalesce(h.ansible_groups, []), "identity")][0], null),
    try([for k, h in var.compute_hosts : k if h.role == "identity"][0], null),
    try(sort(keys(var.compute_hosts))[0], null),
  )

  # Subdomain = identity_domain with the trailing ".${base_domain}" stripped.
  # "auth.example.org" with base_domain="example.org" → "auth".
  # "auth.staging.example.org" with base_domain="staging.example.org" → "auth".
  gateway_subdomain = trimsuffix(replace(var.identity_domain, ".${var.base_domain}", ""), ".${var.base_domain}")
}

resource "scaleway_domain_record" "gateway" {
  count    = var.manage_gateway_dns ? 1 : 0
  provider = scaleway.dns

  dns_zone = var.base_domain
  name     = local.gateway_subdomain
  type     = "A"
  data     = module.compute_host[local.gateway_host_key].ip_address
  ttl      = var.gateway_dns_ttl
}
