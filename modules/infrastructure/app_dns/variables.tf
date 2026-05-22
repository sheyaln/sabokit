variable "dns_records" {
  description = "DNS records to create, keyed by domain. Each value is a list of records. A records need `server`; CNAMEs need `target`. Records whose domain or server can't be resolved against the lookup maps are silently dropped."
  type = map(list(object({
    subdomain = string
    type      = string
    server    = optional(string)
    target    = optional(string)
    ttl       = optional(number, 3600)
  })))
  default = {}
}

variable "domain_zones" {
  description = "Map of domain key → Scaleway DNS zone ID. Domain keys not present here are skipped (lets consumers gate records on optional zones)."
  type        = map(string)
  default     = {}
}

variable "server_ips" {
  description = "Map of server name → public IP. A records whose `server` isn't in this map (or maps to null) are skipped (lets consumers gate records on optional servers like staging)."
  type        = map(string)
  default     = {}
}
