#!/usr/bin/env bash
# Infra layer — Scaleway substrate (VPC, compute, Postgres incl. Authentik's DB,
# TEM, gateway DNS, secrets). Pure terraform; apply this first.
#
#   scripts/infra.sh <env>
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"
log "infra: terraform apply ($ENV)"
tf_apply "$ENV" infra
log "infra done — hosts, Postgres, and the Authentik bootstrap secrets are up."
