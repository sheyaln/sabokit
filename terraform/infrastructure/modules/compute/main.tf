terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
  }
}

# IP Address for the instance
resource "scaleway_instance_ip" "this" {
}

# Server instance
resource "scaleway_instance_server" "this" {
  name              = var.instance_name
  type              = var.instance_type
  image             = var.image
  ip_id             = scaleway_instance_ip.this.id
  security_group_id = var.security_group_id

  root_volume {
    size_in_gb  = var.disk_size
    volume_type = var.disk_type
  }

  private_network {
    pn_id = var.private_network_id != "" ? var.private_network_id : null
  }

  additional_volume_ids = var.additional_volume_ids

  # First-boot bootstrap via cloud-init. Re-creating the instance re-runs it;
  # editing in place does not.
  user_data = var.user_data

  tags = var.tags
}
