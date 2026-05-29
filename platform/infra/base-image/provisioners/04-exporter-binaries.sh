#!/usr/bin/env bash
# Install node_exporter + cadvisor native binaries under /usr/local/bin and
# drop systemd units (disabled — Ansible's monitoring-agent role uses docker
# compose, but the binaries are useful for local debugging and for sites that
# want to swap to systemd-only later).
#
# Versions and SHA256s come from env vars (set by Packer from
# variables.pkr.hcl). Every download is checksum-verified — a tampered or
# moved release asset fails the build before any binary lands on the image.

set -euo pipefail

: "${NODE_EXPORTER_VERSION:?NODE_EXPORTER_VERSION is required}"
: "${CADVISOR_VERSION:?CADVISOR_VERSION is required}"
: "${NODE_EXPORTER_SHA256_AMD64:?NODE_EXPORTER_SHA256_AMD64 is required}"
: "${NODE_EXPORTER_SHA256_ARM64:?NODE_EXPORTER_SHA256_ARM64 is required}"
: "${CADVISOR_SHA256_AMD64:?CADVISOR_SHA256_AMD64 is required}"
: "${CADVISOR_SHA256_ARM64:?CADVISOR_SHA256_ARM64 is required}"

ARCH_DPKG="$(dpkg --print-architecture)"
case "${ARCH_DPKG}" in
  amd64)
    GO_ARCH="amd64"
    NE_SHA="${NODE_EXPORTER_SHA256_AMD64}"
    CA_SHA="${CADVISOR_SHA256_AMD64}"
    ;;
  arm64)
    GO_ARCH="arm64"
    NE_SHA="${NODE_EXPORTER_SHA256_ARM64}"
    CA_SHA="${CADVISOR_SHA256_ARM64}"
    ;;
  *) echo "Unsupported arch: ${ARCH_DPKG}"; exit 1 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# ── node_exporter ───────────────────────────────────────────────────────────
NE_TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.linux-${GO_ARCH}.tar.gz"
curl -fsSL --retry 3 \
  "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NE_TARBALL}" \
  -o "${TMP}/${NE_TARBALL}"
echo "${NE_SHA}  ${TMP}/${NE_TARBALL}" | sha256sum -c -
tar -xzf "${TMP}/${NE_TARBALL}" -C "${TMP}"
install -m 0755 \
  "${TMP}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${GO_ARCH}/node_exporter" \
  /usr/local/bin/node_exporter

install -d -m 0755 /var/lib/node_exporter/textfile_collector

cat >/etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus node_exporter
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# ── cadvisor ────────────────────────────────────────────────────────────────
curl -fsSL --retry 3 \
  "https://github.com/google/cadvisor/releases/download/v${CADVISOR_VERSION}/cadvisor-v${CADVISOR_VERSION}-linux-${GO_ARCH}" \
  -o "${TMP}/cadvisor"
echo "${CA_SHA}  ${TMP}/cadvisor" | sha256sum -c -
install -m 0755 "${TMP}/cadvisor" /usr/local/bin/cadvisor

cat >/etc/systemd/system/cadvisor.service <<'EOF'
[Unit]
Description=cAdvisor container metrics
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cadvisor -logtostderr
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Units exist but are NOT started/enabled — the running services come from
# the monitoring-agent docker-compose stack.
systemctl daemon-reload
