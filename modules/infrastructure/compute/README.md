# compute

Provisions one Scaleway instance with a dedicated public IP, root volume, and private-network attachment. Caller supplies the security group and private network; the module allocates the instance IP itself.

`user_data` is for first-boot cloud-init bootstrapping only — re-creating the instance re-runs it, editing in place does not. Use the `additional_volume_ids` escape hatch to attach pre-existing volumes (e.g. block-storage data disks managed elsewhere).

The `image` input defaults to `ubuntu_jammy` (Scaleway marketplace label, Ubuntu 22.04 LTS). Pass a Scaleway image UUID instead to boot from a custom image — most commonly the `fc-base-<version>` image produced by `packer/` and imported via `consumer-template/scripts/import-base-image.sh`. The pre-baked image cuts Ansible bootstrap time by roughly 5×; the `ubuntu_jammy` path still works, just slower.

## Usage

```hcl
module "tools" {
  source = "git::https://github.com/sheyaln/sabokit.git//modules/infrastructure/compute?ref=v2.0.0"

  instance_name      = "tools-prod"
  instance_type      = "PRO2-S"
  disk_size          = 80
  private_network_id = module.private_network.id
  security_group_id  = module.tools_sg.id
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `instance_name` | `string` | — | Name of the instance. |
| `instance_type` | `string` | `"DEV1-S"` | Instance type. |
| `image` | `string` | `"ubuntu_jammy"` | Base image. Marketplace label (e.g. `ubuntu_jammy`) or a Scaleway image UUID. See note above on `fc-base-<version>` custom images. |
| `disk_size` | `number` | `30` | Root volume size in GB. |
| `disk_type` | `string` | `"l_ssd"` | Root volume type. Must be `l_ssd` or `sbs_volume`. |
| `private_network_id` | `string` | — | Private network ID. |
| `protected` | `bool` | `false` | Protect the instance from deletion. |
| `tags` | `list(string)` | `[]` | Tags to apply to the instance. |
| `security_group_id` | `string` | — | Security group ID to assign to this instance. |
| `additional_volume_ids` | `list(string)` | `[]` | List of additional volume IDs to attach to the instance. |
| `user_data` | `map(string)` | `{}` | Map of cloud-init / user_data entries passed to the instance. Common keys: `cloud-init` (yaml string), `cloud-config` (yaml string). Empty map = no first-boot bootstrap. |

## Outputs

| Name | Description |
|------|-------------|
| `ip_address` | Public IP address of the instance. |
| `private_ip` | Private network IPv4 address of the instance. |
| `instance_id` | ID of the instance. |
| `instance_name` | Name of the instance. |
