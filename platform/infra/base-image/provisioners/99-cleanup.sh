#!/usr/bin/env bash
# Final cleanup before snapshot. Goal: every clone of this image boots clean,
# carries no build-time identity, and leaks no build-time artefacts to a
# forensic reader.
#
# What this does NOT do:
#   - Lock the `packer` user / remove cloud-init sudoers: done by the
#     shutdown_command in base.pkr.hcl (atomic with poweroff so the build's
#     own sudo still authenticates).
#   - userdel + rm -rf /home/packer: done by the systemd one-shot installed
#     by 08-firstboot-lockdown.sh, which fires once on first boot of any
#     cloned host (can't userdel a logged-in user).

set -euo pipefail

# ── apt cache ───────────────────────────────────────────────────────────────
apt-get -y autoremove --purge
apt-get -y clean
rm -rf /var/lib/apt/lists/* \
       /var/cache/apt/archives/partial \
       /var/cache/apt/*.bin \
       /var/cache/debconf/*-old

# ── logs (text + binary + journal) ──────────────────────────────────────────
# Text logs: truncate so paths stay valid for services that open them on
# first boot; gzipped rotations get deleted outright.
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
find /var/log -type f \( -name "*.gz" -o -name "*.[0-9]" -o -name "*.[0-9].*" \) -delete || true

# Binary logs: build-time logins / failed-auth attempts hang around in these
# until explicitly cleared.
: >/var/log/wtmp
: >/var/log/btmp
: >/var/log/lastlog

# Journal: vacuum to ~minimum, then drop persisted directory so each clone
# starts fresh (systemd recreates it on first boot if Storage=persistent).
journalctl --rotate || true
journalctl --vacuum-size=1M || true
rm -rf /var/log/journal/*

# ── machine identity ────────────────────────────────────────────────────────
truncate -s 0 /etc/machine-id || true
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# systemd's random seed is per-instance. Carrying the same seed across every
# clone weakens early-boot PRNG output.
rm -f /var/lib/systemd/random-seed

# ── ssh host keys ───────────────────────────────────────────────────────────
# CRITICAL: any host key surviving the snapshot is shared by every cloned VM,
# enabling trivial MITM and impersonation by anyone with a copy of the image.
# The ssh-keygen systemd unit on Ubuntu cloud images regenerates per-host
# keys on first boot when these are absent.
rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

# Anyone's authorized_keys for any account on the source image — wipe.
rm -rf /root/.ssh
rm -rf /home/*/.ssh

# ── cloud-init state ────────────────────────────────────────────────────────
cloud-init clean --logs --seed 2>/dev/null || true
rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance 2>/dev/null || true

# ── shell history ───────────────────────────────────────────────────────────
rm -f /root/.bash_history /home/*/.bash_history 2>/dev/null || true
rm -f /root/.viminfo /home/*/.viminfo 2>/dev/null || true
history -c 2>/dev/null || true

# ── /tmp + /var/tmp ─────────────────────────────────────────────────────────
# Provisioners use mktemp + trap, but a failed run or out-of-band write may
# have left artefacts. Wipe.
rm -rf /tmp/* /tmp/.[!.]* 2>/dev/null || true
rm -rf /var/tmp/* /var/tmp/.[!.]* 2>/dev/null || true

# ── hostname ────────────────────────────────────────────────────────────────
# The build VM's hostname (fc-base-build) shouldn't leak. cloud-init resets
# /etc/hostname on first boot, but we clear here too so a consumer who
# disables cloud-init still gets a generic name.
echo 'localhost' >/etc/hostname
sed -i '/127\.0\.1\.1\s\+fc-base-build/d' /etc/hosts

# ── zero free space ─────────────────────────────────────────────────────────
# Helps qcow2 sparse compression. Must come last — any write after this
# undoes the work.
dd if=/dev/zero of=/EMPTY bs=1M status=none || true
rm -f /EMPTY
sync
