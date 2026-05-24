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

# ── OnlyOffice (connector app + document server URL + JWT) ──
# The documentserver container reads JWT_SECRET natively from its env. The
# Nextcloud-side onlyoffice app needs the same value to sign edit sessions;
# we push it in via occ. config:app:set is idempotent.
ONLYOFFICE_PUBLIC_URL="$(ce ONLYOFFICE_PUBLIC_URL)"
ONLYOFFICE_INTERNAL_URL="$(ce ONLYOFFICE_INTERNAL_URL)"
ONLYOFFICE_STORAGE_URL="$(ce ONLYOFFICE_STORAGE_URL)"
ONLYOFFICE_JWT_SECRET="$(ce JWT_SECRET)"

if [[ -n "${ONLYOFFICE_PUBLIC_URL}" && -n "${ONLYOFFICE_JWT_SECRET}" ]]; then
    if ! occ app:list 2>/dev/null | grep -q "^  - onlyoffice:"; then
        occ app:install onlyoffice >/dev/null || true
        note_change
    fi
    occ app:enable onlyoffice >/dev/null
    occ config:app:set onlyoffice DocumentServerUrl --value="${ONLYOFFICE_PUBLIC_URL}/" >/dev/null
    occ config:app:set onlyoffice DocumentServerInternalUrl --value="${ONLYOFFICE_INTERNAL_URL}" >/dev/null
    occ config:app:set onlyoffice StorageUrl --value="${ONLYOFFICE_STORAGE_URL}" >/dev/null
    occ config:app:set onlyoffice jwt_secret --value="${ONLYOFFICE_JWT_SECRET}" >/dev/null
    occ config:app:set onlyoffice jwt_header --value="Authorization" >/dev/null
    # Self-signed/Let's-encrypt issues between containers would otherwise
    # break the internal callback. The internal URL is HTTP-only and stays
    # on the docker bridge — no MITM exposure.
    occ config:app:set onlyoffice verify_peer_off --value="true" >/dev/null
fi

# ── Talk HPB (spreed app + STUN/TURN/signaling backends) ──
# Three secrets, three roles:
#   TALK_TURN_SECRET      — HMAC for time-bound TURN credentials between
#                           clients and eturnal.
#   TALK_SIGNALING_SECRET — backend-secret shared between Nextcloud and the
#                           standalone signaling server; lets Nextcloud
#                           authenticate room events.
#   TALK_INTERNAL_SECRET  — Janus ↔ signaling internal auth; never leaves
#                           the HPB container.
TALK_HOST="$(ce TALK_HOST)"
TALK_PORT="$(ce TALK_PORT)"
TALK_TURN_SECRET="$(ce TALK_TURN_SECRET)"
TALK_SIGNALING_SECRET="$(ce TALK_SIGNALING_SECRET)"

if [[ -n "${TALK_HOST}" && -n "${TALK_PORT}" ]]; then
    if ! occ app:list 2>/dev/null | grep -q "^  - spreed:"; then
        occ app:install spreed >/dev/null || true
        note_change
    fi
    occ app:enable spreed >/dev/null

    # STUN: bare host:port, JSON array of strings.
    occ config:app:set spreed stun_servers \
        --value="[\"${TALK_HOST}:${TALK_PORT}\"]" >/dev/null

    # TURN: omit the turn:/turns: scheme — Nextcloud prefixes it based on
    # the "protocols" field. Wrong shape = silent media failures.
    occ config:app:set spreed turn_servers \
        --value="[{\"server\":\"${TALK_HOST}:${TALK_PORT}\",\"secret\":\"${TALK_TURN_SECRET}\",\"protocols\":\"udp,tcp\"}]" >/dev/null

    # External signaling URL is the WSS endpoint Traefik fronts on 443.
    occ config:app:set spreed signaling_servers \
        --value="{\"servers\":[{\"server\":\"wss://${TALK_HOST}\",\"verify\":true}],\"secret\":\"${TALK_SIGNALING_SECRET}\"}" >/dev/null

    occ config:app:set spreed signaling_mode --value="external" >/dev/null || true

    # E2E call encryption disabled: the server middleware enforces
    # min-client-version 99.0.0 when E2E is on, which blanket-rejects every
    # current Android/iOS Talk build with HTTP 426. Re-enable once mobile
    # apps catch up.
    occ config:app:set spreed call_end_to_end_encryption --value="0" >/dev/null
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

# ── Instance identity ──
NEXTCLOUD_INSTANCE_NAME="$(ce NEXTCLOUD_INSTANCE_NAME)"
if [[ -n "${NEXTCLOUD_INSTANCE_NAME}" ]]; then
    CURRENT_NAME="$(occ config:system:get instancename 2>/dev/null || true)"
    if [[ "${CURRENT_NAME}" != "${NEXTCLOUD_INSTANCE_NAME}" ]]; then
        occ config:system:set instancename --value="${NEXTCLOUD_INSTANCE_NAME}" >/dev/null
        note_change
    fi
fi

# ── Nightly maintenance window ──
MAINTENANCE_WINDOW_START="$(ce MAINTENANCE_WINDOW_START)"
if [[ -n "${MAINTENANCE_WINDOW_START}" ]]; then
    CURRENT_WIN="$(occ config:system:get maintenance_window_start 2>/dev/null || true)"
    if [[ "${CURRENT_WIN}" != "${MAINTENANCE_WINDOW_START}" ]]; then
        occ config:system:set maintenance_window_start --value="${MAINTENANCE_WINDOW_START}" --type=integer >/dev/null
        note_change
    fi
fi

# ── App auto-enable / auto-disable ──
# Both lists are space-separated. occ app:enable is idempotent; install
# happens first (also idempotent, returns nonzero if already installed which
# we swallow).
NEXTCLOUD_ENABLED_APPS="$(ce NEXTCLOUD_ENABLED_APPS)"
for app in ${NEXTCLOUD_ENABLED_APPS}; do
    if ! occ app:list 2>/dev/null | grep -q "^  - ${app}:"; then
        occ app:install "${app}" >/dev/null 2>&1 || true
        note_change
    fi
    occ app:enable "${app}" >/dev/null 2>&1 || true
done

NEXTCLOUD_DISABLED_APPS="$(ce NEXTCLOUD_DISABLED_APPS)"
for app in ${NEXTCLOUD_DISABLED_APPS}; do
    if occ app:list 2>/dev/null | grep -q "^  - ${app}:"; then
        occ app:disable "${app}" >/dev/null 2>&1 || true
    fi
done

# ── File handling defaults ──
# Preview thumbnails, JPEG quality, distributed file locking, retention.
occ config:system:set preview_max_x --value="2048" --type=integer >/dev/null
occ config:system:set preview_max_y --value="2048" --type=integer >/dev/null
occ config:system:set jpeg_quality --value="60" --type=integer >/dev/null
occ config:system:set filelocking.enabled --value="true" --type=boolean >/dev/null
occ config:system:set versions_retention_obligation --value="auto, 30" >/dev/null
occ config:system:set activity_expire_days --value="365" --type=integer >/dev/null
# Log rotate at 100 MB.
occ config:system:set log_rotate_size --value="104857600" --type=integer >/dev/null

# ── n8n webhook registration for Nextcloud Forms submissions ──
# Idempotent: list existing webhooks via OCS API, register only if the
# target URL isn't already present. Requires the webhook_listeners app
# (auto-enabled above when included in NEXTCLOUD_ENABLED_APPS).
N8N_FORM_WEBHOOK_URL="$(ce N8N_FORM_WEBHOOK_URL)"
if [[ -n "${N8N_FORM_WEBHOOK_URL}" ]]; then
    ADMIN_USER="$(ce NEXTCLOUD_ADMIN_USER)"
    ADMIN_PASSWORD="$(ce NEXTCLOUD_ADMIN_PASSWORD)"
    TRUSTED_DOMAIN="$(ce NEXTCLOUD_TRUSTED_DOMAINS)"

    if [[ -n "${ADMIN_USER}" && -n "${ADMIN_PASSWORD}" && -n "${TRUSTED_DOMAIN}" ]]; then
        WEBHOOK_EVENT='OCA\Forms\Events\FormSubmittedEvent'
        OCS_URL="https://${TRUSTED_DOMAIN}/ocs/v2.php/apps/webhook_listeners/api/v1/webhooks"

        EXISTING="$(curl -fsS -u "${ADMIN_USER}:${ADMIN_PASSWORD}" \
            -H 'OCS-APIRequest: true' \
            -H 'Accept: application/json' \
            "${OCS_URL}" 2>/dev/null || true)"

        if ! echo "${EXISTING}" | grep -Fq "${N8N_FORM_WEBHOOK_URL}"; then
            CODE="$(curl -s -o /dev/null -w '%{http_code}' \
                -X POST \
                -u "${ADMIN_USER}:${ADMIN_PASSWORD}" \
                -H 'OCS-APIRequest: true' \
                -H 'Content-Type: application/json' \
                -d "{\"httpMethod\":\"POST\",\"uri\":\"${N8N_FORM_WEBHOOK_URL}\",\"event\":\"${WEBHOOK_EVENT}\"}" \
                "${OCS_URL}")"
            if [[ "${CODE}" =~ ^2 ]]; then
                note_change
            else
                echo "WARN: webhook_listeners registration returned HTTP ${CODE}" >&2
            fi
        fi
    fi
fi

# ── Repair pass (catches the file-locking + apps_paths fallout from the
# above changes). Expensive checks are bounded; this is safe to run on
# every play.
occ maintenance:repair --include-expensive >/dev/null 2>&1 || true

if (( DID_CHANGE == 1 )); then
    echo "CHANGED"
fi
exit 0
