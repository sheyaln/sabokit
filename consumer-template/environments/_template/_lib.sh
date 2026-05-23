#!/usr/bin/env bash
# Shared helpers for up.sh and configure.sh. Source this; don't run it.
#
#   . "$(dirname "$0")/_lib.sh"
#
# After sourcing, the following are available:
#   ENV_DIR, ENV_NAME, FED_COMMONS_DIR  — set + verified
#   GATEWAY_DOMAIN, SCW_PROJECT_ID, INFRA_EMAIL  — read from terraform.tfvars
#   SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID,
#     SCW_DEFAULT_REGION, SCW_DEFAULT_ZONE  — exported (single credential
#     source for the Scaleway provider; suppresses the "Multiple variable
#     sources detected" warning)
#   SCW_CONFIG_PATH=/dev/null  — disables operator's ~/.config/scw/config.yaml
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

# Configure the Scaleway provider entirely via SCW_* env vars, exported here
# from terraform.tfvars (with TF_VAR_* / pre-existing SCW_* as overrides for
# CI). The provider.tf block is intentionally empty.
#
# Why: the Scaleway provider emits a multi-line "Multiple variable sources
# detected" warning on every plan/apply when more than one of {active profile
# in ~/.config/scw/config.yaml, provider{} block, environment variable}
# supplies the same credential. Funneling everything through env vars (and
# disabling the operator's config.yaml below) collapses that to a single
# source per variable, so the warning never fires.
#
# Side benefit: the same SCW_* values also drive the `scw` CLI calls in
# up.sh / configure.sh (DNS record updates, secret reads), so there's exactly
# one source of truth for which Scaleway project these scripts target.

# Disable ~/.config/scw/config.yaml. Pointing SCW_CONFIG_PATH at a missing
# file is the SDK's documented "no config" signal — both the terraform
# provider and the `scw` CLI handle ConfigFileNotFoundError as "use env vars
# only". Prevents operator's daily-driver active profile from leaking in.
export SCW_CONFIG_PATH=/dev/null
unset SCW_PROFILE

# Pull a Scaleway value from the first source that defines it:
#   1. SCW_<NAME>            (already in env)
#   2. TF_VAR_<tfvar_name>   (terraform's standard override)
#   3. terraform.tfvars      (project-pinned default)
_resolve_scw() {
  local scw_env="$1" tf_var="$2"
  if [[ -n "${!scw_env:-}" ]]; then printf '%s' "${!scw_env}"; return; fi
  local tfvar_env="TF_VAR_${tf_var}"
  if [[ -n "${!tfvar_env:-}" ]]; then printf '%s' "${!tfvar_env}"; return; fi
  tfvar "$tf_var"
}

SCW_ACCESS_KEY_RESOLVED="$(_resolve_scw SCW_ACCESS_KEY scaleway_access_key)"
SCW_SECRET_KEY_RESOLVED="$(_resolve_scw SCW_SECRET_KEY scaleway_secret_key)"
SCW_REGION_RESOLVED="$(_resolve_scw SCW_DEFAULT_REGION scaleway_region)"
SCW_ZONE_RESOLVED="$(_resolve_scw SCW_DEFAULT_ZONE scaleway_zone)"

[[ -n "$SCW_ACCESS_KEY_RESOLVED" ]] || { c_err "scaleway_access_key not set (env SCW_ACCESS_KEY, TF_VAR_scaleway_access_key, or terraform.tfvars)."; exit 1; }
[[ -n "$SCW_SECRET_KEY_RESOLVED" ]] || { c_err "scaleway_secret_key not set (env SCW_SECRET_KEY, TF_VAR_scaleway_secret_key, or terraform.tfvars)."; exit 1; }

export SCW_ACCESS_KEY="$SCW_ACCESS_KEY_RESOLVED"
export SCW_SECRET_KEY="$SCW_SECRET_KEY_RESOLVED"
# Project is always pinned to terraform.tfvars — defeats operator's daily
# SCW_DEFAULT_PROJECT_ID leaking in and applying staging into prod.
export SCW_DEFAULT_PROJECT_ID="$SCW_PROJECT_ID"
export SCW_DEFAULT_REGION="${SCW_REGION_RESOLVED:-fr-par}"
export SCW_DEFAULT_ZONE="${SCW_ZONE_RESOLVED:-fr-par-1}"

# Always init — cheap when warm, recovers from a fresh clone otherwise.
terraform init -backend-config=backend.hcl -input=false >/dev/null
