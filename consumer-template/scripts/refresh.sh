#!/usr/bin/env bash
# Regenerate the derived files ansible consumes — inventory.ini and
# .enabled_apps.json — from whatever terraform state the layers have. Run
# after any out-of-band terraform change; the layer scripts run it themselves.
#
#   scripts/refresh.sh <env>
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ENV="${1:-}"; require_env "$ENV"

regen_inventory "$ENV"
build_enabled_apps "$ENV"
