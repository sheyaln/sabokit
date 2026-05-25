# A record for the app hostname → the deployment host's public IP.

resource "scaleway_domain_record" "this" {
  count = var.enabled ? 1 : 0

  dns_zone = var.base.domains.base_domain
  name     = replace(var.hostname, ".${var.base.domains.base_domain}", "")
  type     = "A"
  data     = var.base.compute.hosts[var.deployment_host_key].public_ip
  ttl      = 300
}
