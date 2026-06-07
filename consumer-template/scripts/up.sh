#!/usr/bin/env bash
# Full bring-up, in dependency order: infra -> identity -> operations ->
# application. Each layer is idempotent; re-run a single layer's script for a
# faster targeted redeploy.
#
#   scripts/up.sh <env>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib.sh"

ENV="${1:-}"; require_env "$ENV"

"$HERE/infra.sh"       "$ENV"
"$HERE/identity.sh"    "$ENV"
"$HERE/operations.sh"  "$ENV"
"$HERE/application.sh" "$ENV"

log "up: $ENV fully deployed."
