# app_dns

Data-driven DNS record provisioning. Consumers load their record spec from anywhere (YAML, JSON, inline locals) and pass it as structured data; the module flattens it into one `scaleway_domain_record` per record.

Records whose `domain_key` isn't in `domain_zones` are silently dropped — lets consumers conditionally provision zones (e.g. a staging zone that exists only when `staging_domain != tools_domain`). The same applies to A records whose `server` isn't in `server_ips`, covering "staging IP not known yet" cases without forcing a split apply. All created records have `prevent_destroy = true`.

## Usage

```hcl
module "app_dns" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/app_dns?ref=v2.2.0"

  dns_records = yamldecode(file("config/dns.yml")).records
  domain_zones = {
    primary = "example.org"
    staging = "staging.example.org"
  }
  server_ips = {
    tools      = module.tools.ip_address
    management = module.management.ip_address
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `dns_records` | `map(list(object({ subdomain, type, server?, target?, ttl? })))` | `{}` | DNS records to create, keyed by domain. Each value is a list of records. A records need `server`; CNAMEs need `target`. Records whose domain or server can't be resolved against the lookup maps are silently dropped. |
| `domain_zones` | `map(string)` | `{}` | Map of domain key → Scaleway DNS zone ID. Domain keys not present here are skipped (lets consumers gate records on optional zones). |
| `server_ips` | `map(string)` | `{}` | Map of server name → public IP. A records whose `server` isn't in this map (or maps to null) are skipped (lets consumers gate records on optional servers like staging). |

## Outputs

| Name | Description |
|------|-------------|
| `a_record_ids` | Map of unique_key to A record ID. Keys are formatted as `domain_key` + underscore + `subdomain` (with asterisks replaced by `wildcard`). |
| `cname_record_ids` | Map of unique_key to CNAME record ID. |
