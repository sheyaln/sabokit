#!/usr/bin/env bash
# Install Docker Engine + Compose plugin from Docker's official apt repo. The
# steps mirror what platform/base/ansible/roles/docker does, so the role's
# guard (which keys on `docker --version`) will skip these on the rendered
# image.

set -euo pipefail

ARCH="$(dpkg --print-architecture)"
. /etc/os-release
CODENAME="${VERSION_CODENAME}"

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable
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
