#!/usr/bin/env bash
# Pre-pull the monitoring-agent + Traefik + HAProxy docker images so first-boot
# `docker compose up` doesn't pay the registry round-trip. Images are passed in
# pinned by digest (see IMAGE_* env vars below) — `docker pull foo:tag@sha256:abc`
# rejects any tag that doesn't resolve to that exact digest, so registry
# tampering or a moved tag fails the build instead of silently shipping.
#
# A consumer who pins their Ansible role to a different tag pays one image
# round-trip on first boot instead of the full set — still a big win on a
# slow link.

set -euo pipefail

: "${IMAGE_NODE_EXPORTER:?IMAGE_NODE_EXPORTER is required (image@sha256:digest)}"
: "${IMAGE_CADVISOR:?IMAGE_CADVISOR is required}"
: "${IMAGE_ALLOY:?IMAGE_ALLOY is required}"
: "${IMAGE_TRAEFIK:?IMAGE_TRAEFIK is required}"
: "${IMAGE_HAPROXY:?IMAGE_HAPROXY is required}"

# Bring docker up just for the pull, then stop it again so the image hands
# off clean.
systemctl start docker.service

IMAGES=(
  "${IMAGE_NODE_EXPORTER}"
  "${IMAGE_CADVISOR}"
  "${IMAGE_ALLOY}"
  "${IMAGE_TRAEFIK}"
  "${IMAGE_HAPROXY}"
)

for img in "${IMAGES[@]}"; do
  echo "Pre-pulling ${img}"
  docker pull "${img}"
done

# Record exactly what got baked so consumers / auditors can diff against an
# expected manifest without booting the image and running `docker images`.
manifest="/etc/sabokit-image-digests.json"
{
  printf '{\n'
  last=$(( ${#IMAGES[@]} - 1 ))
  for i in "${!IMAGES[@]}"; do
    img="${IMAGES[$i]}"
    sep=','
    [ "$i" -eq "$last" ] && sep=''
    printf '  "%s": "%s"%s\n' "${img%@*}" "${img##*@}" "$sep"
  done
  printf '}\n'
} >"${manifest}"
chmod 0644 "${manifest}"

systemctl stop docker.service docker.socket containerd.service
