#!/usr/bin/env bash
# Stamp the image so Ansible roles can detect they're running on a pre-baked
# sabokit host and skip redundant install steps. The marker file
# format is intentionally simple — shell-sourceable.

set -euo pipefail

: "${SABOKIT_BASE_VERSION:?SABOKIT_BASE_VERSION is required}"

cat >/etc/sabokit-base-image <<EOF
# Sabokit pre-baked base image marker. Presence of this file tells
# Ansible roles to skip the static apt-install / binary-download steps that
# Packer already ran. See packer/README.md.
SABOKIT_BASE_VERSION=${SABOKIT_BASE_VERSION}
SABOKIT_BASE_BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
chmod 0644 /etc/sabokit-base-image
