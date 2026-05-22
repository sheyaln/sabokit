# common_security_rules

Renders standard inbound-rule bundles (HTTPS, HTTP, SSH, DNS, TURN/STUN, Wazuh manager, monitoring scrape ports) toggled by boolean flags, and returns them as a single `inbound_rules` list. Feed the output straight into a `security_group` module, or concat with consumer-specific extras.

The module creates no Scaleway resources — it is a pure data transformation. Toggle bundles on/off without rewriting rule literals on every host.

## Usage

```hcl
module "tools_rules" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/common_security_rules?ref=v1.0.0"

  enable_https    = true
  enable_http     = true
  enable_ssh      = true
  monitoring_cidr = "10.42.0.5/32"
}

module "tools_sg" {
  source        = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/security_group?ref=v1.0.0"
  name          = "tools-prod-sg"
  inbound_rules = module.tools_rules.inbound_rules
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enable_https` | `bool` | `true` | Allow inbound HTTPS (TCP+UDP 443) from anywhere. UDP 443 carries HTTP/3. |
| `enable_http` | `bool` | `true` | Allow inbound HTTP (TCP 80) from anywhere. Needed for Let's Encrypt HTTP-01 challenge and 80-to-443 redirect. |
| `enable_ssh` | `bool` | `true` | Allow inbound SSH (TCP 22) from anywhere. |
| `enable_dns` | `bool` | `false` | Allow inbound DNS (TCP+UDP 53). Only needed for hosts running a public DNS resolver. |
| `enable_turn_stun` | `bool` | `false` | Allow inbound TURN/STUN ports (TCP+UDP 3478 + UDP 49152-49252) for Nextcloud Talk / WebRTC relays. |
| `enable_wazuh_manager` | `bool` | `false` | Allow inbound ports for hosting a Wazuh manager (TCP 1514, TCP 1515, UDP 514). |
| `monitoring_cidr` | `string` | `null` | If non-null, allow Node Exporter (9100), cAdvisor (8080), and Promtail (9080) from this CIDR only. Typically the management host's private IP. null = no monitoring rules. |

## Outputs

| Name | Description |
|------|-------------|
| `inbound_rules` | Combined list of inbound rules from all enabled bundles. Feed directly into a `scaleway/security_group` module's `inbound_rules` input, or concat with consumer-specific extras. |
