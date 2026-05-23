// Builds the sabokit base image: a Scaleway custom image that ships
// the static, version-agnostic bits the Ansible bootstrap would otherwise
// install on every fresh host (docker engine + compose, ufw, fail2ban,
// unattended-upgrades, node_exporter + cadvisor binaries, scw CLI, jq,
// python3 + Scaleway SDK, monitoring docker images pre-pulled).
//
// Per-env configuration (Traefik certs, scw-secrets render, Authentik compose,
// Alloy config) stays in Ansible — only the static OS/package layer moves here.
//
// Cutting the slow apt-install steps out of bootstrap is worth roughly a 5×
// speed-up on a cold deploy. The resulting image is fully compatible with the
// existing bootstrap.yml — the Ansible role guards detect a pre-baked image
// (via /etc/fc-base-image) and skip the redundant install steps.

packer {
  required_plugins {
    scaleway = {
      source  = "github.com/hashicorp/scaleway"
      version = ">= 1.1.0"
    }
  }
}

source "scaleway" "base" {
  access_key          = var.scaleway_access_key
  secret_key          = var.scaleway_secret_key
  project_id          = var.scaleway_project_id
  zone                = var.scaleway_zone
  commercial_type     = var.instance_type
  image               = var.source_image
  image_name          = "${var.image_name_prefix}-${var.image_version}"
  snapshot_name       = "${var.image_name_prefix}-${var.image_version}"
  ssh_username        = "root"
  remove_volume       = true
  image_tags          = [
    "sabokit",
    "fc-base",
    "version:${var.image_version}",
  ]
}

build {
  name    = "fc-base"
  sources = ["source.scaleway.base"]

  // Apt base layer: refresh, upgrade, install package-managed bits.
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
    ]
    script = "./provisioners/01-apt-base.sh"
  }

  // Docker engine + compose plugin from Docker's official apt repo.
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
    ]
    script = "./provisioners/02-docker.sh"
  }

  // Pre-pull monitoring images so the bootstrap `docker compose up` doesn't
  // pay the round-trip to gcr.io / Docker Hub on first boot.
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
    ]
    script = "./provisioners/03-monitoring-images.sh"
  }

  // node_exporter + cadvisor native binaries. Systemd units are placed but
  // NOT enabled — the running services are provided by docker-compose in
  // the monitoring-agent role. Binaries are a fallback / power-user escape
  // hatch.
  provisioner "shell" {
    environment_vars = [
      "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
      "CADVISOR_VERSION=${var.cadvisor_version}",
    ]
    script = "./provisioners/04-exporter-binaries.sh"
  }

  // Scaleway CLI binary. Ansible scw-secrets role already has a version guard,
  // so an older pre-baked binary is fine — it gets upgraded in-place if
  // scw_cli_version is set to "latest" or a higher pin.
  provisioner "shell" {
    environment_vars = [
      "SCW_CLI_VERSION=${var.scw_cli_version}",
    ]
    script = "./provisioners/05-scw-cli.sh"
  }

  // Stamp the image so Ansible roles can detect they're running on a
  // pre-baked host and skip redundant install steps.
  provisioner "shell" {
    environment_vars = [
      "FC_BASE_VERSION=${var.image_version}",
    ]
    script = "./provisioners/06-stamp-image.sh"
  }

  // Final cleanup: clear apt caches, machine-id, cloud-init seed so the image
  // boots clean on every clone.
  provisioner "shell" {
    script = "./provisioners/99-cleanup.sh"
  }
}
