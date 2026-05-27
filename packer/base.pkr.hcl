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

  // Lock the build-time `packer` user atomically with shutdown — once sudo
  // authenticates, the root shell continues even after the password is
  // disabled, so packer can still power the VM off. Doing the lockdown in
  // 99-cleanup.sh instead would invalidate the password before this command
  // runs, breaking the build.
  shutdown_command = "echo 'packer' | sudo -S sh -c 'passwd -l packer; chage -E 0 packer; rm -f /etc/sudoers.d/90-cloud-init-users; shutdown -P now'"

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

  // Pre-pull monitoring images, pinned by sha256 digest so registry tampering
  // or a moved tag fails the build instead of silently baking a different
  // image into the snapshot.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env DEBIAN_FRONTEND=noninteractive {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "IMAGE_NODE_EXPORTER=${var.image_node_exporter}",
      "IMAGE_CADVISOR=${var.image_cadvisor}",
      "IMAGE_ALLOY=${var.image_alloy}",
      "IMAGE_TRAEFIK=${var.image_traefik}",
      "IMAGE_HAPROXY=${var.image_haproxy}",
    ]
    script = "./provisioners/03-monitoring-images.sh"
  }

  // node_exporter + cadvisor native binaries. SHA256-verified. Systemd units
  // are placed but NOT enabled — the running services come from docker-compose
  // in the monitoring-agent role. Binaries are a fallback / escape hatch.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
      "CADVISOR_VERSION=${var.cadvisor_version}",
      "NODE_EXPORTER_SHA256_AMD64=${var.node_exporter_sha256_amd64}",
      "NODE_EXPORTER_SHA256_ARM64=${var.node_exporter_sha256_arm64}",
      "CADVISOR_SHA256_AMD64=${var.cadvisor_sha256_amd64}",
      "CADVISOR_SHA256_ARM64=${var.cadvisor_sha256_arm64}",
    ]
    script = "./provisioners/04-exporter-binaries.sh"
  }

  // Scaleway CLI binary, SHA256-verified. Ansible scw-secrets role already
  // has a version guard, so an older pre-baked binary is fine — it gets
  // upgraded in-place if scw_cli_version is set to a higher pin.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "SCW_CLI_VERSION=${var.scw_cli_version}",
      "SCW_CLI_SHA256_AMD64=${var.scw_cli_sha256_amd64}",
      "SCW_CLI_SHA256_ARM64=${var.scw_cli_sha256_arm64}",
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

  // OS hardening: sshd drop-in, sysctl kernel tuning, login.defs tightening,
  // ufw default-deny baseline (staged, enabled on first boot by the
  // sabokit-firstboot-cleanup service installed below).
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env DEBIAN_FRONTEND=noninteractive {{ .Vars }} {{ .Path }}"
    script          = "./provisioners/07-hardening.sh"
  }

  // Install the systemd one-shot that fires once on first boot: deletes the
  // packer user + home, enables ufw, then disables itself. Lives here (not
  // in 99-cleanup.sh) because it has to outlive the qcow2 snapshot.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    script          = "./provisioners/08-firstboot-lockdown.sh"
  }

  // Final cleanup: apt caches, logs (text + binary + journal), machine-id,
  // ssh host keys, cloud-init seed, /tmp, /var/tmp, hostname, zero free
  // space. Every clone boots clean.
  provisioner "shell" {
    execute_command = "echo 'packer' | sudo -S env {{ .Vars }} {{ .Path }}"
    script          = "./provisioners/99-cleanup.sh"
  }
}
