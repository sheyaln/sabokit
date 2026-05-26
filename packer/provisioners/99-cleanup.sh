#!/usr/bin/env bash
# Final cleanup before snapshot: shrink apt caches, clear machine-id and
# cloud-init seed so the image boots clean on every clone, zero out free
# space (helps compress the qcow2 export).

set -euo pipefail

apt-get -y autoremove
apt-get -y clean
rm -rf /var/lib/apt/lists/*

# Truncate logs created during the build.
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
find /var/log -type f \( -name "*.gz" -o -name "*.1" \) -delete || true
journalctl --rotate || true
journalctl --vacuum-time=1s || true

# Reset machine identity. systemd recreates this on first boot; cloud-init
# also re-seeds on first boot.
truncate -s 0 /etc/machine-id || true
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Clear cloud-init cached state — we want a fresh first-boot on every clone.
cloud-init clean --logs --seed 2>/dev/null || true
rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance 2>/dev/null || true

# Clear shell history.
rm -f /root/.bash_history /home/*/.bash_history 2>/dev/null || true
history -c 2>/dev/null || true

# Lock the build-time `packer` user so it can't log back in on the shipped
# image. We can't `userdel` while a packer-owned shell is still alive (the
# shutdown_command runs as packer); cloud-init on the consumer side seeds
# the runtime accounts (root, deploy) afresh on first boot anyway.
passwd -l packer 2>/dev/null || true
rm -f /etc/sudoers.d/90-cloud-init-users
chage -E 0 packer 2>/dev/null || true

# Zero free space (optional, helps qcow2 compression).
dd if=/dev/zero of=/EMPTY bs=1M status=none || true
rm -f /EMPTY
sync
