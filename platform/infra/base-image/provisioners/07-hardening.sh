#!/usr/bin/env bash
# OS-level hardening baked into the base image: sshd drop-in, sysctl tuning,
# login.defs tightening, default-deny ufw baseline. All applied via drop-in
# files so apt upgrades don't fight them.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ── sshd hardening ──────────────────────────────────────────────────────────
# Ubuntu jammy ships /etc/ssh/sshd_config with `Include /etc/ssh/sshd_config.d/*.conf`
# at the top — verify before writing, fail loudly if the OS changed shape.
if ! grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config; then
  echo "ERROR: /etc/ssh/sshd_config has no Include directive for sshd_config.d/*.conf" >&2
  echo "       Drop-in approach won't apply. Aborting." >&2
  exit 1
fi

install -d -m 0755 /etc/ssh/sshd_config.d

# Drop-in fragment. The `00-` prefix wins over any later snippet alphabetically;
# sshd uses *first match wins* for most directives, so this file's settings
# take precedence over /etc/ssh/sshd_config defaults.
cat >/etc/ssh/sshd_config.d/00-sabokit-hardening.conf <<'EOF'
# Sabokit hardened sshd defaults. Drop-in baked at packer build time.
# Override per-host by adding a higher-numbered file under
# /etc/ssh/sshd_config.d/ — first match wins.

# Auth surface
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
MaxAuthTries 3
MaxSessions 4
LoginGraceTime 30

# Forwarding: allow local (ansible tunnels DB ports etc.) but not remote/X11/agent.
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding local

# Session liveness
ClientAliveInterval 300
ClientAliveCountMax 2

# Banner / protocol
Protocol 2
Banner none

# Modern crypto — Mozilla "modern" OpenSSH profile, trimmed to algorithms
# present in OpenSSH 8.9 (Ubuntu jammy).
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256,rsa-sha2-256-cert-v01@openssh.com
EOF
chmod 0644 /etc/ssh/sshd_config.d/00-sabokit-hardening.conf

# Validate the merged config. `sshd -t` parses every Include'd file and exits
# non-zero on any syntax / unsupported-algorithm error — fail the build here
# instead of shipping a broken image.
sshd -t -f /etc/ssh/sshd_config

# Host keys are wiped by 99-cleanup.sh; ssh-keygen.service regenerates them on
# first boot. Intentionally NOT restarting sshd here — we're connected to the
# build VM over SSH right now; restart kills the provisioner.

# ── sysctl kernel hardening ─────────────────────────────────────────────────
# CIS Ubuntu 22.04 baseline subset — kernel info leakage, IP-stack abuse,
# SYN-flood resilience. Leaves performance-tuning to the consumer's role.
cat >/etc/sysctl.d/99-sabokit-hardening.conf <<'EOF'
# Kernel info exposure
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 1
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# IPv4 stack
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# IPv6 stack
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
EOF
chmod 0644 /etc/sysctl.d/99-sabokit-hardening.conf

# ── login.defs tightening ───────────────────────────────────────────────────
# Tighter default umask + password aging. Affects users created after this
# image is rendered (cloud-init seeds; Ansible role accounts).
sed -i \
  -e 's/^\(UMASK\s\+\).*/\1027/' \
  -e 's/^\(PASS_MAX_DAYS\s\+\).*/\1365/' \
  -e 's/^\(PASS_MIN_DAYS\s\+\).*/\11/' \
  -e 's/^\(PASS_WARN_AGE\s\+\).*/\17/' \
  /etc/login.defs

# Defensive: if any of those keys weren't present (Ubuntu has all three but
# guard for derivatives), append.
grep -q '^UMASK ' /etc/login.defs        || echo 'UMASK 027'        >>/etc/login.defs
grep -q '^PASS_MAX_DAYS ' /etc/login.defs || echo 'PASS_MAX_DAYS 365' >>/etc/login.defs

# ── ufw default-deny baseline ───────────────────────────────────────────────
# Closes the bootstrap window between cloud-init bringing the host online and
# Ansible configuring per-role firewall rules. Allow 22/tcp so the Ansible
# controller can land; everything else is denied. Ansible's ufw role overlays
# per-app allows on top.
#
# Enabled on first boot via the systemd one-shot installed by
# 08-firstboot-lockdown.sh — leaving ufw disabled now keeps the build-time
# ssh session alive.
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'ssh bootstrap'
