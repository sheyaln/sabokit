#!/usr/bin/env bash
# Identity layer — boot Authentik, then configure it.
#
# Rhythm: ansible bootstrap boots the Authentik server container (using the
# secrets infra minted), THEN terraform configures Authentik through its API.
# This is the one layer that deploys before it applies. Between the two sit
# the slow physics of a first boot: SSH reachability, gateway DNS
# propagation, the Let's Encrypt cert, and Authentik indexing its built-in
# flows — each gated explicitly so a re-run picks up wherever it left off.
#
#   scripts/identity.sh <env> [extra ansible args...]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"; shift || true

# Inventory + the secret-id map the authentik-server role plants.
regen_inventory "$ENV"
IB="$(tf "$ENV" infra output -json identity_bootstrap)"

log "identity: waiting for ssh on the compute hosts"
wait_ssh_hosts "$ENV"

# Host bootstrap: docker, traefik, monitoring-agent (Alloy), and the Authentik
# server. Alloy is wired to push at the ops host now (it buffers until loki/
# prometheus come up in the operations layer).
log "identity: ansible bootstrap (boots Authentik + host base)"
run_ansible "$ENV" bootstrap \
  -e "identity_bootstrap=${IB}" \
  $(ops_extra_vars "$ENV") \
  "$@"

GATEWAY="$(env_value "$ENV" identity_domain)"
[ -n "$GATEWAY" ] || die "identity_domain not set in $(env_dir "$ENV")/env.yml"

log "identity: waiting for DNS on ${GATEWAY}"
wait_for "DNS for ${GATEWAY}" 600 10 dns_resolves "$GATEWAY"

# https_200 verifies TLS, so this gate doubles as the Let's Encrypt wait —
# traefik's self-signed placeholder cert can't pass it.
log "identity: waiting for Authentik behind a valid cert (https://${GATEWAY})"
wait_for "https://${GATEWAY}/api/v3/root/config/ to return 200" 600 10 \
  https_200 "https://${GATEWAY}/api/v3/root/config/"

# Configure Authentik via the API: tier groups + nesting, flows, branding.
fetch_authentik_token "$ENV"

log "identity: waiting for Authentik to index its built-in flows + RBAC"
wait_for "Authentik flow/RBAC indexing" 300 5 \
  authentik_indexed "$GATEWAY" "$TF_VAR_authentik_admin_token"

log "identity: terraform apply (configures Authentik)"
tf_apply "$ENV" identity
log "identity done."
