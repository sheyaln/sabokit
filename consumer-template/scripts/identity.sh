#!/usr/bin/env bash
# Identity layer — boot Authentik, then configure it.
#
# Rhythm: ansible bootstrap boots the Authentik server container (using the
# secrets infra minted), THEN terraform configures Authentik through its API.
# This is the one layer that deploys before it applies.
#
#   scripts/identity.sh <env>
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"

# Inventory + the secret-id map the authentik-server role plants.
regen_inventory "$ENV"
IB="$(tf "$ENV" infra output -json identity_bootstrap)"

# Host bootstrap: docker, traefik, monitoring-agent (Alloy), and the Authentik
# server. Alloy is wired to push at the ops host now (it buffers until loki/
# prometheus come up in the operations layer).
log "identity: ansible bootstrap (boots Authentik + host base)"
run_ansible "$ENV" bootstrap \
  -e "identity_bootstrap=${IB}" \
  $(ops_extra_vars "$ENV")

# Configure Authentik via the API: tier groups + nesting, flows, branding.
log "identity: terraform apply (configures Authentik)"
fetch_authentik_token "$ENV"
tf_apply "$ENV" identity
log "identity done."
