terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
  }
}

resource "scaleway_vpc_private_network" "this" {
  name   = var.name
  region = var.region
  tags   = var.tags
  vpc_id = var.vpc_id

  dynamic "ipv4_subnet" {
    for_each = var.subnet == null ? [] : [var.subnet]
    content {
      subnet = ipv4_subnet.value
    }
  }
}
