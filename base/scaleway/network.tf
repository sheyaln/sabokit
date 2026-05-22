module "network" {
  source = "../../modules/infrastructure/network"

  name   = "${local.name_suffix}-network"
  region = var.scaleway_region
  subnet = var.private_network_subnet
  tags   = local.base_tags
}
