#!/usr/bin/env bash
# Install a systemd one-shot that fires once on first boot of any host cloned
# from this image. It finishes the work `99-cleanup.sh` can't do while still
# logged in as the packer user (deleting that user, deleting its home dir)
# and flips ufw on so the host is firewalled before sshd accepts external
# connections. Service deletes itself after the first successful run.

set -euo pipefail

install -d -m 0755 /usr/local/sbin

cat >/usr/local/sbin/sabokit-firstboot-cleanup.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# Delete the build-time packer user and its home dir. By the time this runs
# (before any login service), no shell owns the account so `userdel -r` works.
if id packer >/dev/null 2>&1; then
  userdel -rf packer 2>/dev/null || true
fi
rm -rf /home/packer

# The build-time cloud-init seed wrote this; cloud-init re-creates it for the
# runtime users on this same boot. Remove first so we don't carry the packer
# entry into the merged sudoers state.
rm -f /etc/sudoers.d/90-cloud-init-users

# Flip ufw on with the default-deny baseline baked by 07-hardening.sh. The
# Ansible role overlays per-app allows on top of this on its first run.
if command -v ufw >/dev/null 2>&1; then
  ufw --force enable >/dev/null || true
fi

# Disable + remove the unit so this only runs once.
systemctl disable sabokit-firstboot-cleanup.service 2>/dev/null || true
rm -f /etc/systemd/system/sabokit-firstboot-cleanup.service \
      /etc/systemd/system/multi-user.target.wants/sabokit-firstboot-cleanup.service \
      /usr/local/sbin/sabokit-firstboot-cleanup.sh
SCRIPT
chmod 0755 /usr/local/sbin/sabokit-firstboot-cleanup.sh

cat >/etc/systemd/system/sabokit-firstboot-cleanup.service <<'EOF'
[Unit]
Description=Sabokit first-boot cleanup (delete build user, enable ufw)
ConditionPathExists=/usr/local/sbin/sabokit-firstboot-cleanup.sh
# Run after cloud-init has seeded the runtime users (so we don't delete
# /etc/sudoers.d/90-cloud-init-users *before* cloud-init rewrites it).
After=cloud-final.service
Wants=cloud-final.service
# But before sshd accepts traffic — otherwise the host is briefly exposed
# without ufw.
Before=ssh.service
DefaultDependencies=yes

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/sabokit-firstboot-cleanup.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /etc/systemd/system/sabokit-firstboot-cleanup.service

systemctl daemon-reload
systemctl enable sabokit-firstboot-cleanup.service
