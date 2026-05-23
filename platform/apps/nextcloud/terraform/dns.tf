resource "scaleway_domain_record" "this" {
  count = var.enabled ? 1 : 0

  dns_zone = var.base.domains.base_domain
  name     = replace(var.hostname, ".${var.base.domains.base_domain}", "")
  type     = "A"
  data     = var.base.compute.hosts[var.deployment_host_key].public_ip
  ttl      = 300
}

# OnlyOffice runs on the same host as Nextcloud, but the browser loads the
# editor IFrame from this hostname directly — Traefik routes it to the
# documentserver container.
resource "scaleway_domain_record" "onlyoffice" {
  count = var.enabled ? 1 : 0

  dns_zone = var.base.domains.base_domain
  name     = replace(var.onlyoffice_hostname, ".${var.base.domains.base_domain}", "")
  type     = "A"
  data     = var.base.compute.hosts[var.deployment_host_key].public_ip
  ttl      = 300
}

# Talk HPB. Same A record covers two things: HTTPS WSS signaling routed via
# Traefik AND the eturnal TURN server on UDP/TCP 3478 bound directly to the
# host. Keep both on one hostname so clients only ever resolve one name.
resource "scaleway_domain_record" "talk" {
  count = var.enabled ? 1 : 0

  dns_zone = var.base.domains.base_domain
  name     = replace(var.talk_hostname, ".${var.base.domains.base_domain}", "")
  type     = "A"
  data     = var.base.compute.hosts[var.deployment_host_key].public_ip
  ttl      = 300
}
