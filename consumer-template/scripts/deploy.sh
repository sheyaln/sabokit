#!/usr/bin/env bash
# Ansible-only redeploy — no terraform apply. Refreshes the derived files,
# then runs the given tags (default: every enabled app). Use the layer
# scripts instead when terraform-managed objects (DBs, OIDC apps, DNS)
# changed too.
#
#   scripts/deploy.sh <env> [tags] [extra ansible args...]
#
#   scripts/deploy.sh prod                       # all apps
#   scripts/deploy.sh prod espocrm               # one app
#   scripts/deploy.sh prod espocrm --check       # dry-run
#   scripts/deploy.sh prod operations            # ops tier only
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"; shift || true
TAGS="${1:-application}"
if [ $# -gt 0 ]; then shift; fi

regen_inventory "$ENV"
build_enabled_apps "$ENV" >/dev/null
run_ansible "$ENV" "$TAGS" $(ops_extra_vars "$ENV") "$@"
