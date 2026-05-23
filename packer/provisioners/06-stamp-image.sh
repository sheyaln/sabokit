#!/usr/bin/env bash
# Stamp the image so Ansible roles can detect they're running on a pre-baked
# sabokit host and skip redundant install steps. The marker file
# format is intentionally simple — shell-sourceable.

set -euo pipefail

: "${FC_BASE_VERSION:?FC_BASE_VERSION is required}"

cat >/etc/fc-base-image <<EOF
# Federated Commons pre-baked base image marker. Presence of this file tells
# Ansible roles to skip the static apt-install / binary-download steps that
# Packer already ran. See packer/README.md.
FC_BASE_VERSION=${FC_BASE_VERSION}
FC_BASE_BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
chmod 0644 /etc/fc-base-image
