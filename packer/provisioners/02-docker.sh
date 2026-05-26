#!/usr/bin/env bash
# Install Docker Engine + Compose plugin from Docker's official apt repo. The
# steps mirror what platform/base/ansible/roles/docker does, so the role's
# guard (which keys on `docker --version`) will skip these on the rendered
# image.

set -euo pipefail

ARCH="$(dpkg --print-architecture)"
. /etc/os-release
CODENAME="${VERSION_CODENAME}"
# Docker hosts separate apt repos per distro family. The packer build can run
# against either a Debian or Ubuntu cloud qcow2 — pick the right one.
case "${ID}" in
  debian) DOCKER_DISTRO="debian" ;;
  ubuntu) DOCKER_DISTRO="ubuntu" ;;
  *) echo "Unsupported distro: ${ID}"; exit 1 ;;
esac

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DOCKER_DISTRO} ${CODENAME} stable
EOF

apt-get update
apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Disable until first real boot: Ansible re-renders /etc/docker/daemon.json
# and starts the service then.
systemctl disable --now docker.service docker.socket containerd.service 2>/dev/null || true
