#!/usr/bin/env bash
# Application layer — the user-facing app suite + the forward-auth outpost.
#
# Rhythm: terraform mints per-app DBs + OIDC apps + the embedded outpost, THEN
# ansible deploys the containers. The churn layer — re-run freely as apps come
# and go.
#
#   scripts/application.sh <env>
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"

log "application: terraform apply (apps + outpost)"
fetch_authentik_token "$ENV"
tf_apply "$ENV" application

log "application: ansible deploy"
regen_inventory "$ENV"
build_enabled_apps "$ENV" >/dev/null
run_ansible "$ENV" application
log "application done."
