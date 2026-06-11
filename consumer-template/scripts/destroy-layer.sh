#!/usr/bin/env bash
# Destroy a single layer's terraform. Reverse-dependency safety is on the
# operator: destroy application/operations before identity, identity before
# infra (scripts/down.sh sequences all four correctly).
#
#   scripts/destroy-layer.sh <env> <infra|identity|operations|application>
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"
LAYER="${2:-}"
case "$LAYER" in
  infra|identity|operations|application) ;;
  *) die "usage: $(basename "$0") <env> <infra|identity|operations|application>" ;;
esac

# The Authentik-provider layers need the admin token to destroy their
# objects; it lives in an infra-owned secret, so it's gone once infra is.
if [ "$LAYER" != "infra" ]; then
  fetch_authentik_token "$ENV"
fi

log "destroy: terraform destroy ($ENV/$LAYER)"
tf_destroy "$ENV" "$LAYER"
log "destroy: $ENV/$LAYER destroyed."
