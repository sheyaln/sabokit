#!/usr/bin/env bash
# Install the Scaleway CLI binary at /usr/local/bin/scw, SHA256-verified
# against the value pinned in variables.pkr.hcl. The scw-secrets Ansible role
# checks for this and skips its download path when found, then upgrades
# in-place if the configured `scw_cli_version` is newer.

set -euo pipefail

: "${SCW_CLI_VERSION:?SCW_CLI_VERSION is required}"
: "${SCW_CLI_SHA256_AMD64:?SCW_CLI_SHA256_AMD64 is required}"
: "${SCW_CLI_SHA256_ARM64:?SCW_CLI_SHA256_ARM64 is required}"

ARCH_DPKG="$(dpkg --print-architecture)"
case "${ARCH_DPKG}" in
  amd64) GO_ARCH="amd64"; SCW_SHA="${SCW_CLI_SHA256_AMD64}" ;;
  arm64) GO_ARCH="arm64"; SCW_SHA="${SCW_CLI_SHA256_ARM64}" ;;
  *) echo "Unsupported arch: ${ARCH_DPKG}"; exit 1 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

curl -fsSL --retry 3 \
  "https://github.com/scaleway/scaleway-cli/releases/download/v${SCW_CLI_VERSION}/scaleway-cli_${SCW_CLI_VERSION}_linux_${GO_ARCH}" \
  -o "${TMP}/scw"
echo "${SCW_SHA}  ${TMP}/scw" | sha256sum -c -
install -m 0755 "${TMP}/scw" /usr/local/bin/scw

/usr/local/bin/scw version
