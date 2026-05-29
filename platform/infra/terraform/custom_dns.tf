# Consumer-declared DNS records (MX/TXT/SRV/AAAA/A/CNAME) at the base layer.
# Co-exists with TEM's auto-managed SPF/DKIM/DMARC (those are owned by
# tem.tf) and with per-app DNS modules (those manage their own hostname-
# scoped records). Use this for records the platform doesn't generate
# itself — typically inbound MX records pointing at the consumer's mail
# provider, additional TXT verifications, SRV records.
#
# Zone keying: keyed by the actual zone string (e.g. "example.org"). Lets
# consumers reference zones in tfvars by the domain they own — no separate
# short-key indirection. Unknown zones are dropped silently per the
# app_dns module convention.
module "custom_dns" {
  source = "../../_shared/infrastructure/app_dns"

  dns_records  = var.custom_dns_records
  domain_zones = { for z in distinct(compact([var.base_domain, local.mgmt_domain])) : z => z }
  server_ips   = { for k, h in module.compute_host : k => h.ip_address }
}
