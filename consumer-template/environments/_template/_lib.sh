#!/usr/bin/env bash
# Shared helpers for up.sh and configure.sh. Source this; don't run it.
#
#   . "$(dirname "$0")/_lib.sh"
#
# After sourcing, the following are available:
#   ENV_DIR, ENV_NAME, FED_COMMONS_DIR  — set + verified
#   GATEWAY_DOMAIN, SCW_PROJECT_ID, INFRA_EMAIL  — read from terraform.tfvars
#   SCW_DEFAULT_PROJECT_ID  — exported (overrides operator's shell value)
#   c_phase, c_ok, c_warn, c_err, c_info  — pretty output
#   tfvar <key>  — extract a string value from terraform.tfvars
#   require_files <paths...>  — assert files exist or exit
#
# We also `terraform init` so the rest of the script can assume modules and
# providers are present.

set -euo pipefail

ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
ENV_NAME="$(basename "$ENV_DIR")"
FED_COMMONS_DIR="${FED_COMMONS_DIR:-${ENV_DIR}/../../../sabokit}"

if [[ ! -d "$FED_COMMONS_DIR/platform/ansible" ]]; then
  echo "ERROR: sabokit not found at $FED_COMMONS_DIR" >&2
  echo "       Set FED_COMMONS_DIR to override, or add sabokit as a submodule." >&2
  exit 1
fi

cd "$ENV_DIR"

# ── Pretty output ───────────────────────────────────────────────────────────

c_phase() { printf "\n\033[1;36m=== %s ===\033[0m\n" "$*"; }
c_ok()    { printf "  \033[32m✓\033[0m %s\n" "$*"; }
c_warn()  { printf "  \033[33m!\033[0m %s\n" "$*"; }
c_err()   { printf "  \033[31m✗\033[0m %s\n" "$*"; }
c_info()  { printf "  → %s\n" "$*"; }

# ── Helpers ─────────────────────────────────────────────────────────────────

# Extract `key = "value"` from terraform.tfvars. Strings only.
tfvar() {
  awk -v key="$1" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, ""); gsub(/^"|"[[:space:]]*$/, "")
      sub(/[[:space:]]*#.*$/, ""); print; exit
    }
  ' terraform.tfvars
}

require_files() {
  local missing=()
  for f in "$@"; do [[ -f "$f" ]] || missing+=("$f"); done
  if (( ${#missing[@]} > 0 )); then
    for f in "${missing[@]}"; do c_err "missing file: $f"; done
    exit 1
  fi
}

# ── Required files + values ─────────────────────────────────────────────────

require_files terraform.tfvars backend.hcl

GATEWAY_DOMAIN="$(tfvar gateway_domain || true)"
SCW_PROJECT_ID="$(tfvar scaleway_project_id || true)"
INFRA_EMAIL="$(tfvar infra_email || true)"
[[ -n "$GATEWAY_DOMAIN" ]] || { c_err "gateway_domain not set in terraform.tfvars.";   exit 1; }
[[ -n "$SCW_PROJECT_ID" ]] || { c_err "scaleway_project_id not set in terraform.tfvars."; exit 1; }
[[ -n "$INFRA_EMAIL"    ]] || { c_err "infra_email not set in terraform.tfvars.";       exit 1; }

# Force the Scaleway provider to use the project from terraform.tfvars, even
# when the operator has SCW_DEFAULT_PROJECT_ID exported for their daily shell.
# The provider silently prefers env vars over explicit provider-block
# project_id; without this override, multi-project users can accidentally
# apply staging resources into their prod project.
export SCW_DEFAULT_PROJECT_ID="$SCW_PROJECT_ID"
unset SCW_PROFILE

# Always init — cheap when warm, recovers from a fresh clone otherwise.
terraform init -backend-config=backend.hcl -input=false >/dev/null
