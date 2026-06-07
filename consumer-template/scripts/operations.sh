#!/usr/bin/env bash
# Operations layer — observability + protonmail-bridge.
#
# Rhythm: terraform mints DBs + OIDC apps against the running Authentik, THEN
# ansible deploys the containers. Host-services (per-host watchers) ride along
# here since wazuh-agent needs the wazuh manager this layer deploys.
#
#   scripts/operations.sh <env>
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"

log "operations: terraform apply (DBs + OIDC apps)"
fetch_authentik_token "$ENV"
tf_apply "$ENV" operations

log "operations: ansible deploy"
regen_inventory "$ENV"
build_enabled_apps "$ENV" >/dev/null
run_ansible "$ENV" operations $(ops_extra_vars "$ENV")
run_ansible "$ENV" host-services
log "operations done."
