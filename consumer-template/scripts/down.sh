#!/usr/bin/env bash
# Full teardown, reverse order: application -> operations -> identity -> infra.
# The Authentik-bound layers are destroyed while infra (which holds the admin
# token secret) is still up; infra goes last.
#
#   scripts/down.sh <env>
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"

# Token needed to destroy the authentik-provider layers; infra is still up here.
fetch_authentik_token "$ENV" || true

tf_destroy "$ENV" application || true
tf_destroy "$ENV" operations  || true
tf_destroy "$ENV" identity    || true
tf_destroy "$ENV" infra

log "down: $ENV destroyed."
