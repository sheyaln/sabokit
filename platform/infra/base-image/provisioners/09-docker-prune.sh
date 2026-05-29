#!/usr/bin/env bash
# Install a weekly docker disk-reclaim timer. Unlike the exporter units (which
# ship disabled because their running form comes from docker-compose), this is
# pure host maintenance with no per-env config — same class as unattended-
# upgrades — so it ships ENABLED and runs on every host cloned from this image
# without waiting on Ansible.
#
# Reclaims: unused images older than the retention window, build cache, and any
# container json-log that escaped rotation. Volumes are deliberately NOT pruned
# — a detached data volume is indistinguishable from junk to `volume prune`,
# and that data loss isn't worth the few hundred MB it would reclaim.

set -euo pipefail

# Operator-tunable knobs. Editable on a live host (no image rebuild); the
# service reads them via EnvironmentFile.
cat >/etc/default/docker-prune <<'EOF'
# Retention window for `docker image prune` / `builder prune` (--filter until=).
# 168h = 7 days, so roughly a week of rollback image tags survives a prune.
DOCKER_PRUNE_RETENTION_HOURS=168
# Container json-logs larger than this get truncated as a safety net. Rotation
# (compose logging: + daemon.json) should prevent it, but a container that
# loops faster than the rotation window can still outrun it.
DOCKER_PRUNE_LOG_THRESHOLD=1G
EOF
chmod 0644 /etc/default/docker-prune

install -d -m 0755 /usr/local/sbin
cat >/usr/local/sbin/docker-prune.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

RETENTION_HOURS="${DOCKER_PRUNE_RETENTION_HOURS:-168}"
LOG_THRESHOLD="${DOCKER_PRUNE_LOG_THRESHOLD:-1G}"

# Safety net: zero any container log that escaped docker's rotation. Truncating
# a live container's json-log is safe — the daemon holds the fd and keeps
# appending past the truncation point.
find /var/lib/docker/containers -name '*-json.log' -size "+${LOG_THRESHOLD}" \
  -exec truncate -s 0 {} \; 2>/dev/null || true

# Images not used by any container, created before the retention window.
docker image prune -af --filter "until=${RETENTION_HOURS}h"
# Build cache older than the retention window.
docker builder prune -f --filter "until=${RETENTION_HOURS}h"
SCRIPT
chmod 0755 /usr/local/sbin/docker-prune.sh

cat >/etc/systemd/system/docker-prune.service <<'EOF'
[Unit]
Description=Reclaim docker disk (unused images, build cache, runaway logs)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
EnvironmentFile=-/etc/default/docker-prune
ExecStart=/usr/local/sbin/docker-prune.sh
# Maintenance yields to real workload.
Nice=10
IOSchedulingClass=idle
EOF
chmod 0644 /etc/systemd/system/docker-prune.service

cat >/etc/systemd/system/docker-prune.timer <<'EOF'
[Unit]
Description=Weekly docker disk reclaim

[Timer]
OnCalendar=Sun *-*-* 04:00:00
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
EOF
chmod 0644 /etc/systemd/system/docker-prune.timer

systemctl daemon-reload
systemctl enable docker-prune.timer
