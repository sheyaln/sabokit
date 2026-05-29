module "compute_host" {
  source   = "../../_shared/infrastructure/compute"
  for_each = var.compute_hosts

  instance_name      = "${local.name_suffix}-${each.key}"
  instance_type      = each.value.instance_type
  image              = each.value.image
  disk_size          = each.value.disk_size
  disk_type          = each.value.disk_type
  private_network_id = module.network.id
  security_group_id  = each.value.security_group_id != null ? each.value.security_group_id : module.role_sg[each.value.role].id
  protected          = each.value.protected
  user_data          = each.value.user_data
  tags               = concat(local.base_tags, each.value.tags, [each.value.role])
}
