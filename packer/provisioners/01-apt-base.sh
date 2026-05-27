#!/usr/bin/env bash
# Refresh apt, install base utilities + firewall + auto-update tooling.
# Idempotent: re-running on a host that already has these is a no-op.

set -euo pipefail

# Hold off on any apt autorun while we work.
systemctl stop unattended-upgrades.service 2>/dev/null || true
systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

# Wait out any apt lock from cloud-init's first-boot run.
for _ in $(seq 1 60); do
  if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

apt-get update
apt-get -y upgrade

apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  jq \
  ufw \
  fail2ban \
  unattended-upgrades \
  mailutils \
  logrotate \
  python3 \
  python3-pip \
  python3-venv \
  python3-docker \
  rsyslog

# Python Scaleway SDK — required by the scaleway.scaleway.scaleway_secret
# Ansible lookup, which runs on the controller. Baking it here doesn't help the
# controller; we install it anyway because some on-host helper scripts call
# the SDK directly during bootstrap, and consumers occasionally run
# `ansible-playbook` from the managed node itself in single-VM setups.
pip3 install --no-cache-dir --break-system-packages \
  scaleway \
  pyyaml || \
pip3 install --no-cache-dir scaleway pyyaml

# Don't start ufw / fail2ban yet — the image gets cloned across many hosts and
# we don't want stale state. Ansible will start them on first boot; ufw is
# also flipped on by sabokit-firstboot-cleanup.service before sshd accepts
# external connections.
systemctl disable --now ufw 2>/dev/null || true
systemctl disable --now fail2ban 2>/dev/null || true

# Configure unattended-upgrades to apply security updates automatically.
# Ubuntu's default 50unattended-upgrades enables the security pocket; we add
# 20auto-upgrades to actually run the timer. Consumers override via Ansible.
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
chmod 0644 /etc/apt/apt.conf.d/20auto-upgrades
