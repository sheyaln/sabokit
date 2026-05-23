# security_group

Creates a Scaleway instance security group with a typed `inbound_rules` list. Rules are expressed as objects (protocol, port or port_range, ip_range); the module renders them into Scaleway's `inbound_rule` blocks. Pair with `common_security_rules` to bundle in standard HTTP/HTTPS/SSH/monitoring rules without restating them per host.

## Usage

```hcl
module "tools_sg" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/security_group?ref=v2.0.0"

  name          = "tools-prod-sg"
  description   = "Tools host"
  inbound_rules = module.common_rules.inbound_rules
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | — | Security group name. |
| `description` | `string` | `""` | Security group description. |
| `inbound_rules` | `list(object({ protocol, port?, port_range?, ip_range? }))` | `[]` | Inbound rules. Each rule: protocol (TCP\|UDP\|ICMP), and either a single port or a port_range, plus an ip_range (defaults to `0.0.0.0/0`). |
| `inbound_default_policy` | `string` | `"drop"` | Default action for inbound traffic that matches no rule. |
| `outbound_default_policy` | `string` | `"accept"` | Default action for outbound traffic that matches no rule. |
| `stateful` | `bool` | `true` | Whether the security group is stateful (return traffic for accepted flows is auto-allowed). |
| `enable_default_security` | `bool` | `false` | Whether Scaleway's default-security rules are applied. Usually false because rules are managed here. |

## Outputs

| Name | Description |
|------|-------------|
| `id` | ID of the security group. |
| `name` | Name of the security group. |
