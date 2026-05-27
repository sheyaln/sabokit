// Builds the sabokit base image: a qcow2 that ships the static,
// version-agnostic bits the Ansible bootstrap would otherwise install on every
// fresh host (docker engine + compose, ufw, fail2ban, unattended-upgrades,
// node_exporter + cadvisor binaries, scw CLI, jq, python3 + Scaleway SDK,
// monitoring docker images pre-pulled).
//
// Per-env configuration (Traefik certs, scw-secrets render, Authentik compose,
// Alloy config) stays in Ansible — only the static OS/package layer moves here.
//
// Cutting the slow apt-install steps out of bootstrap is worth roughly a 5×
// speed-up on a cold deploy. The resulting image is fully compatible with the
// existing bootstrap.yml — the Ansible role guards detect a pre-baked image
// (via /etc/sabokit-base-image) and skip the redundant install steps.
//
// Builder is qemu so the build runs offline against an upstream cloud qcow2 —
// no Scaleway project / API key / object-storage bucket needed. The resulting
// qcow2 is what consumers import into their own Scaleway project via
// `consumer-template/scripts/import-base-image.sh`.

packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
  }
}

source "qemu" "base" {
  iso_url      = var.source_image_url
  iso_checksum = var.source_image_checksum
  disk_image   = true

  output_directory = "${var.output_directory}/fc-base-${var.image_version}"
  vm_name          = "fc-base-${var.image_version}.qcow2"
  format           = "qcow2"

  disk_size          = var.disk_size
  disk_compression   = true
  use_backing_file   = false
  skip_compaction    = false
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"

  memory      = var.memory
  cpus        = var.cpus
  accelerator = var.accelerator
  headless    = true

  // NoCloud datasource via attached cidata CD: cloud-init seeds the build-time
  // `packer` user (password + ssh key) on first boot. `99-cleanup.sh` wipes
  // the resulting authorized_keys + cloud-init state before the qcow2 ships.
  cd_label = "cidata"
  cd_files = [
    "${path.root}/http/user-data",
    "${path.root}/http/meta-data",
  ]

  ssh_username           = "packer"
  ssh_password           = "packer"
  ssh_timeout            = "10m"
  ssh_handshake_attempts = "100"

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  qemuargs = [
    ["-cpu", "host"],
  ]
}

build {
  name    = "fc-base"
  sources = ["source.qemu.base"]

  // Apt base layer: refresh, upgrade, install package-managed bits.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env DEBIAN_FRONTEND=noninteractive {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
    ]
    script = "./provisioners/01-apt-base.sh"
  }

  // Docker engine + compose plugin from Docker's official apt repo.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env DEBIAN_FRONTEND=noninteractive {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
    ]
    script = "./provisioners/02-docker.sh"
  }

  // Pre-pull monitoring images so the bootstrap `docker compose up` doesn't
  // pay the round-trip to gcr.io / Docker Hub on first boot.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env DEBIAN_FRONTEND=noninteractive {{ .Vars }} {{ .Path }}"
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
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
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
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "SCW_CLI_VERSION=${var.scw_cli_version}",
    ]
    script = "./provisioners/05-scw-cli.sh"
  }

  // Stamp the image so Ansible roles can detect they're running on a
  // pre-baked host and skip redundant install steps.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "SABOKIT_BASE_VERSION=${var.image_version}",
    ]
    script = "./provisioners/06-stamp-image.sh"
  }

  // SSH daemon hardening: drop-in fragment under /etc/ssh/sshd_config.d/.
  // Validated via `sshd -t` inside the script; not restarted (build is over
  // SSH — config applies on first boot of cloned hosts).
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env DEBIAN_FRONTEND=noninteractive {{ .Vars }} {{ .Path }}"
    script          = "./provisioners/07-sshd-hardening.sh"
  }

  // Final cleanup: clear apt caches, machine-id, cloud-init seed so the image
  // boots clean on every clone.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    script          = "./provisioners/99-cleanup.sh"
  }
}
