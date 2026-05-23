#!/usr/bin/env bash
# Pre-pull the monitoring-agent docker images so first-boot `docker compose up`
# doesn't pay the registry round-trip. Pinned defaults below mirror the
# defaults in platform/base/ansible/roles/monitoring-agent/defaults/main.yml.
#
# If a consumer pins to a different tag, the bootstrap pull is one image
# round-trip instead of three — still a big win on a slow link.

set -euo pipefail

# Bring docker up just for the pull, then stop it again so the image hands
# off clean.
systemctl start docker.service

IMAGES=(
  "prom/node-exporter:latest"
  "gcr.io/cadvisor/cadvisor:latest"
  "grafana/alloy:latest"
  "traefik:v3.3"
  "library/haproxy:2.9-alpine"
)

for img in "${IMAGES[@]}"; do
  echo "Pre-pulling ${img}"
  docker pull "${img}" || echo "WARN: failed to pull ${img}, continuing"
done

systemctl stop docker.service docker.socket containerd.service
