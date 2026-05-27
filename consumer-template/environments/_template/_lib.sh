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
#   tfvar_value <key>  — extract a string value from terraform.tfvars
#   config_value <key>  — extract a string value from config.tf locals
#   require_files <paths...>  — assert files exist or exit
#
# We also `terraform init` so the rest of the script can assume modules and
# providers are present.
#
# Config layout:
#   terraform.tfvars — per-env values (project_id, domains, instance sizes,
#                      infra_email, environment, network). Gitignored.
#   config.tf        — persistent infra shape (apps catalog, host topology,
#                      tier_slots, org identity). Committable.
#   secrets.tf       — Scaleway Secret Manager data sources. Committable.
#   variables.tf     — per-env variable declarations + runtime credentials.
#
# Credentials NEVER live in terraform.tfvars or config.tf. SCW_ACCESS_KEY +
# SCW_SECRET_KEY must come from the env (or TF_VAR_scaleway_access_key /
# TF_VAR_scaleway_secret_key).

set -euo pipefail

ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
ENV_NAME="$(basename "$ENV_DIR")"
FED_COMMONS_DIR="${FED_COMMONS_DIR:-${ENV_DIR}/../../../sabokit}"
export ENV_DIR ENV_NAME FED_COMMONS_DIR

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

# Extract `key = "value"` from terraform.tfvars. Strings only. Per-env values
# (project_id, domains, infra_email, etc.) live here.
tfvar_value() {
  awk -v key="$1" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, ""); gsub(/^"|"[[:space:]]*$/, "")
      sub(/[[:space:]]*#.*$/, ""); print; exit
    }
  ' terraform.tfvars
}

# Extract `key = "value"` from config.tf. Strings only. Works for any leaf
# string inside `locals { config = { ... } }` because the regex anchors only
# on the leading-whitespace `key = "..."` shape — keeps `config.tf` flat
# enough for shell to read without HCL parsing. Persistent (non-per-env)
# values only — see tfvar_value for per-env reads.
config_value() {
  awk -v key="$1" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, ""); gsub(/^"|"[[:space:]]*$/, "")
      sub(/[[:space:]]*#.*$/, ""); print; exit
    }
  ' config.tf
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

require_files config.tf terraform.tfvars backend.hcl

GATEWAY_DOMAIN="$(tfvar_value gateway_domain || true)"
SCW_PROJECT_ID="$(tfvar_value scaleway_project_id || true)"
INFRA_EMAIL="$(tfvar_value infra_email || true)"
[[ -n "$GATEWAY_DOMAIN" ]] || { c_err "gateway_domain not set in terraform.tfvars."; exit 1; }
[[ -n "$SCW_PROJECT_ID" ]] || { c_err "scaleway_project_id not set in terraform.tfvars."; exit 1; }
[[ -n "$INFRA_EMAIL"    ]] || { c_err "infra_email not set in terraform.tfvars."; exit 1; }

# Configure the Scaleway provider entirely via SCW_* env vars. The provider.tf
# block is intentionally empty so the provider sees exactly one credential
# source (env) instead of three (env + provider-block + ~/.config/scw/config.yaml
# active profile), which produces a noisy "Multiple variable sources detected"
# warning on every plan/apply.
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

# Credentials MUST come from env (SCW_* or TF_VAR_*) — config.tf is
# committable and cannot hold secrets. Region/zone may come from config.tf
# as a project-pinned default.
_first_nonempty() {
  for v in "$@"; do [[ -n "$v" ]] && { printf '%s' "$v"; return; }; done
}

SCW_ACCESS_KEY_RESOLVED="$(_first_nonempty "${SCW_ACCESS_KEY:-}" "${TF_VAR_scaleway_access_key:-}")"
SCW_SECRET_KEY_RESOLVED="$(_first_nonempty "${SCW_SECRET_KEY:-}" "${TF_VAR_scaleway_secret_key:-}")"
SCW_REGION_RESOLVED="$(_first_nonempty "${SCW_DEFAULT_REGION:-}" "${TF_VAR_scaleway_region:-}" "$(tfvar_value scaleway_region || true)")"
SCW_ZONE_RESOLVED="$(_first_nonempty "${SCW_DEFAULT_ZONE:-}" "${TF_VAR_scaleway_zone:-}" "$(tfvar_value scaleway_zone || true)")"

[[ -n "$SCW_ACCESS_KEY_RESOLVED" ]] || { c_err "SCW_ACCESS_KEY not set (env SCW_ACCESS_KEY or TF_VAR_scaleway_access_key). Credentials live in env vars — never in terraform.tfvars or config.tf."; exit 1; }
[[ -n "$SCW_SECRET_KEY_RESOLVED" ]] || { c_err "SCW_SECRET_KEY not set (env SCW_SECRET_KEY or TF_VAR_scaleway_secret_key). Credentials live in env vars — never in terraform.tfvars or config.tf."; exit 1; }

export SCW_ACCESS_KEY="$SCW_ACCESS_KEY_RESOLVED"
export SCW_SECRET_KEY="$SCW_SECRET_KEY_RESOLVED"
# Project is always pinned to terraform.tfvars — defeats operator's daily
# SCW_DEFAULT_PROJECT_ID leaking in and applying staging into prod.
export SCW_DEFAULT_PROJECT_ID="$SCW_PROJECT_ID"
export SCW_DEFAULT_REGION="${SCW_REGION_RESOLVED:-fr-par}"
export SCW_DEFAULT_ZONE="${SCW_ZONE_RESOLVED:-fr-par-1}"
# TF_VAR_* mirrors so the per-env variables.tf credentials picks up the same
# values without forcing operators to export TWO sets of env vars.
export TF_VAR_scaleway_access_key="$SCW_ACCESS_KEY"
export TF_VAR_scaleway_secret_key="$SCW_SECRET_KEY"

# Always init — cheap when warm, recovers from a fresh clone otherwise.
terraform init -backend-config=backend.hcl -input=false >/dev/null
