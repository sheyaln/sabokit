#!/usr/bin/env bash
# Install the Scaleway CLI binary at /usr/local/bin/scw. The scw-secrets
# Ansible role checks for this and skips its download path when found, then
# upgrades in-place if the configured `scw_cli_version` is newer.

set -euo pipefail

: "${SCW_CLI_VERSION:=2.34.0}"

ARCH_DPKG="$(dpkg --print-architecture)"
case "${ARCH_DPKG}" in
  amd64) GO_ARCH="amd64" ;;
  arm64) GO_ARCH="arm64" ;;
  *) echo "Unsupported arch: ${ARCH_DPKG}"; exit 1 ;;
esac

curl -fsSL --retry 3 \
  "https://github.com/scaleway/scaleway-cli/releases/download/v${SCW_CLI_VERSION}/scaleway-cli_${SCW_CLI_VERSION}_linux_${GO_ARCH}" \
  -o /usr/local/bin/scw
chmod 0755 /usr/local/bin/scw

/usr/local/bin/scw version
