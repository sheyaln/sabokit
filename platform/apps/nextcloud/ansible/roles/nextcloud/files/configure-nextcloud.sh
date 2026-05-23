#!/bin/bash
# Idempotent post-install occ configuration. Run after the Nextcloud container
# is healthy. Emits the string "CHANGED" on stdout when any configuration was
# updated so the Ansible task can report a real changed state.
#
# Reads required values from the running container's environment (which is
# populated from .env). Nothing is hardcoded here.

set -euo pipefail

CONTAINER="${NC_CONTAINER:-nextcloud-app}"
DID_CHANGE=0

occ() {
    docker exec -u www-data "${CONTAINER}" php occ "$@"
}

# Pull a value out of the container's env. Used for values the configure
# script needs but which Nextcloud itself does not read from env (e.g.
# OIDC discovery URL).
ce() {
    docker exec "${CONTAINER}" sh -c "printenv '$1' || true"
}

note_change() {
    DID_CHANGE=1
}

# Wait for occ to be available (Nextcloud's first-boot auto-install may still
# be writing config.php).
for _ in $(seq 1 60); do
    if occ status --no-warnings 2>/dev/null | grep -q "installed: true"; then
        break
    fi
    sleep 5
done

if ! occ status --no-warnings 2>/dev/null | grep -q "installed: true"; then
    echo "ERROR: Nextcloud is not installed after waiting 5 minutes." >&2
    exit 1
fi

# ── Reverse-proxy + trusted domain ──
TRUSTED_DOMAIN="$(ce NEXTCLOUD_TRUSTED_DOMAINS)"
TRUSTED_PROXIES="$(ce TRUSTED_PROXIES)"

if [[ -n "${TRUSTED_DOMAIN}" ]]; then
    CURRENT="$(occ config:system:get trusted_domains 0 2>/dev/null || true)"
    if [[ "${CURRENT}" != "${TRUSTED_DOMAIN}" ]]; then
        occ config:system:set trusted_domains 0 --value="${TRUSTED_DOMAIN}"
        note_change
    fi
fi

if [[ -n "${TRUSTED_PROXIES}" ]]; then
    CURRENT="$(occ config:system:get trusted_proxies 0 2>/dev/null || true)"
    if [[ "${CURRENT}" != "${TRUSTED_PROXIES}" ]]; then
        occ config:system:set trusted_proxies 0 --value="${TRUSTED_PROXIES}"
        note_change
    fi
fi

# ── Redis distributed locking + memcache ──
# Nextcloud needs explicit memcache config; env vars alone don't switch it on.
REDIS_PASSWORD="$(ce REDIS_PASSWORD)"
if [[ -n "${REDIS_PASSWORD}" ]]; then
    occ config:system:set redis host --value="nextcloud-redis" >/dev/null
    occ config:system:set redis port --value="6379" >/dev/null
    occ config:system:set redis password --value="${REDIS_PASSWORD}" >/dev/null
    occ config:system:set memcache.local --value='\OC\Memcache\APCu' >/dev/null
    occ config:system:set memcache.distributed --value='\OC\Memcache\Redis' >/dev/null
    occ config:system:set memcache.locking --value='\OC\Memcache\Redis' >/dev/null
fi

# ── S3 integrity flags for Scaleway compatibility (Nextcloud 32+) ──
# Scaleway S3 rejects the AWS SDK's default CRC32 trailing-checksums; relax
# integrity to "when_required" so PUT/GET round-trips succeed.
occ config:system:set objectstore arguments request_checksum_calculation --value="when_required" >/dev/null
occ config:system:set objectstore arguments response_checksum_validation --value="when_required" >/dev/null

# ── Background jobs use cron (the nextcloud-cron container) ──
CURRENT_BG="$(occ config:system:get backgroundjobs_mode 2>/dev/null || true)"
if [[ "${CURRENT_BG}" != "cron" ]]; then
    occ background:cron >/dev/null
    note_change
fi

# ── SSRF allowance for split-horizon DNS ──
# Required when public hostnames resolve to RFC1918 addresses inside the VPC;
# Nextcloud's DnsPinMiddleware otherwise blocks every server-to-server call.
CURRENT_SSRF="$(occ config:system:get allow_local_remote_servers 2>/dev/null || true)"
if [[ "${CURRENT_SSRF}" != "true" ]]; then
    occ config:system:set allow_local_remote_servers --value="true" --type=boolean >/dev/null
    note_change
fi

# ── Forwarded-for headers (Traefik passes both) ──
occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR" >/dev/null
occ config:system:set forwarded_for_headers 1 --value="HTTP_FORWARDED" >/dev/null

# ── Security defaults ──
occ config:system:set auth.bruteforce.protection.enabled --value="true" --type=boolean >/dev/null
occ config:system:set ratelimit.protection.enabled --value="true" --type=boolean >/dev/null

# ── OIDC (Authentik via user_oidc) ──
OIDC_CLIENT_ID="$(ce OIDC_CLIENT_ID)"
OIDC_CLIENT_SECRET="$(ce OIDC_CLIENT_SECRET)"
OIDC_DISCOVERY_URL="$(ce OIDC_DISCOVERY_URL)"
OIDC_PROVIDER_NAME="$(ce OIDC_PROVIDER_NAME)"
OIDC_SCOPES="$(ce OIDC_SCOPES)"

if [[ -n "${OIDC_CLIENT_ID}" && -n "${OIDC_CLIENT_SECRET}" && -n "${OIDC_DISCOVERY_URL}" ]]; then
    if ! occ app:list 2>/dev/null | grep -q "^  - user_oidc:"; then
        occ app:install user_oidc >/dev/null || true
        note_change
    fi
    occ app:enable user_oidc >/dev/null

    # user_oidc:provider is idempotent — it upserts by name.
    occ user_oidc:provider "${OIDC_PROVIDER_NAME}" \
        --clientid="${OIDC_CLIENT_ID}" \
        --clientsecret="${OIDC_CLIENT_SECRET}" \
        --discoveryuri="${OIDC_DISCOVERY_URL}" \
        --scope="${OIDC_SCOPES}" \
        --unique-uid=0 >/dev/null

    occ config:system:set --type boolean --value true hide_login_form >/dev/null
fi

# ── SMTP ──
SMTP_HOST="$(ce SMTP_HOST)"
if [[ -n "${SMTP_HOST}" ]]; then
    SMTP_PORT="$(ce SMTP_PORT)"
    SMTP_NAME="$(ce SMTP_NAME)"
    SMTP_PASSWORD="$(ce SMTP_PASSWORD)"
    SMTP_SECURE="$(ce SMTP_SECURE)"
    MAIL_FROM_ADDRESS="$(ce MAIL_FROM_ADDRESS)"
    MAIL_DOMAIN="$(ce MAIL_DOMAIN)"

    occ config:system:set mail_smtpmode --value="smtp" >/dev/null
    occ config:system:set mail_smtphost --value="${SMTP_HOST}" >/dev/null
    occ config:system:set mail_smtpport --value="${SMTP_PORT}" --type=integer >/dev/null
    occ config:system:set mail_smtpsecure --value="${SMTP_SECURE}" >/dev/null
    occ config:system:set mail_smtpauth --value="1" --type=integer >/dev/null
    occ config:system:set mail_smtpname --value="${SMTP_NAME}" >/dev/null
    occ config:system:set mail_smtppassword --value="${SMTP_PASSWORD}" >/dev/null
    occ config:system:set mail_from_address --value="${MAIL_FROM_ADDRESS}" >/dev/null
    occ config:system:set mail_domain --value="${MAIL_DOMAIN}" >/dev/null
fi

if (( DID_CHANGE == 1 )); then
    echo "CHANGED"
fi
exit 0
