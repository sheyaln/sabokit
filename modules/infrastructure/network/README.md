# network

Creates a Scaleway VPC private network. Pass `vpc_id` to nest it under an existing VPC, or leave null to use the project's default VPC. Pass `subnet` to pin an explicit IPv4 CIDR, or leave null and let Scaleway assign one.

## Usage

```hcl
module "private_network" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/network?ref=v2.3.0"

  name   = "prod-pn"
  subnet = "10.42.0.0/22"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | — | Name of the private network. |
| `region` | `string` | `"fr-par"` | Scaleway region. |
| `tags` | `list(string)` | `[]` | Tags applied to the private network. |
| `vpc_id` | `string` | `null` | Optional: ID of an existing VPC. If null, the private network is created in the project's default VPC. |
| `subnet` | `string` | `null` | Optional: explicit IPv4 CIDR for the private network. If null, Scaleway assigns one automatically. |

## Outputs

| Name | Description |
|------|-------------|
| `id` | ID of the private network. |
| `name` | Name of the private network. |
