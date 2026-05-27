#!/usr/bin/env bash
# Validate consumer-template/apps-manifest.yaml against the real Terraform
# inputs in platform/apps/<id>/terraform/variables.tf for every declared app.
#
# - ERROR: a manifest input that doesn't exist as a `variable` in the HCL.
#   (Manifest lying to consumers — they'll send a tfvar that terraform rejects.)
# - WARN: an HCL variable not present in the manifest. Allowed for internal
#   contract inputs (`base`) and operator-only knobs producer chose not to
#   surface; the warning exists so adding a new user-facing variable upstream
#   doesn't silently miss the wizard.
#
# Dependencies: bash 3.2+, yq (mikefarah), awk, grep.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/consumer-template/apps-manifest.yaml"

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq (mikefarah/yq) required. Install: brew install yq" >&2
  exit 2
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest not found at $MANIFEST" >&2
  exit 2
fi

# Inputs that always exist in HCL but are deliberately excluded from any
# user-facing manifest entry. Not flagged as missing-from-manifest.
INTERNAL_VARS=(base extra_authorized_groups)

# Manifest-only inputs that are consumed by consumer-template wiring (not by
# any bundle HCL variable). Format: "<app_id>:<input_name>". Not flagged as
# manifest-declares-non-existent-variable.
MANIFEST_ONLY_INPUTS=(
  "n8n:broadsheet_membership"
)

errors=0
warnings=0

# Read into bash 3.2-portable arrays (no mapfile).
app_ids=()
while IFS= read -r line; do app_ids+=("$line"); done < <(yq '.apps[].id' "$MANIFEST")

for id in "${app_ids[@]}"; do
  # Tier search order: apps, core, bootstrap. The manifest identifies the
  # bundle by id only; the layout (which tier dir it lives in) is hidden
  # from consumers.
  vars_tf=""
  for tier in apps core bootstrap; do
    candidate="$REPO_ROOT/platform/$tier/$id/terraform/variables.tf"
    if [[ -f "$candidate" ]]; then
      vars_tf="$candidate"
      break
    fi
  done
  if [[ -z "$vars_tf" ]]; then
    echo "ERROR [$id]: declared in manifest but no variables.tf under platform/{apps,core,bootstrap}/$id/terraform/" >&2
    errors=$((errors+1))
    continue
  fi

  manifest_inputs=()
  while IFS= read -r line; do manifest_inputs+=("$line"); done < <(
    yq ".apps[] | select(.id == \"$id\") | .tfvars.schema | keys | .[]" "$MANIFEST"
  )

  hcl_vars=()
  while IFS= read -r line; do hcl_vars+=("$line"); done < <(
    awk '/^variable[[:space:]]+"[^"]+"[[:space:]]*{/ {
      gsub(/^variable[[:space:]]+"/, "")
      gsub(/"[[:space:]]*{.*$/, "")
      print
    }' "$vars_tf"
  )

  # Manifest input → must be a real HCL variable (unless explicitly allowed
  # as a consumer-template-only knob via MANIFEST_ONLY_INPUTS).
  for input in "${manifest_inputs[@]}"; do
    if ! printf '%s\n' "${hcl_vars[@]}" | grep -qxF "$input"; then
      allowed=false
      for mo in "${MANIFEST_ONLY_INPUTS[@]}"; do
        [[ "$mo" == "$id:$input" ]] && { allowed=true; break; }
      done
      $allowed && continue
      echo "ERROR [$id]: manifest declares input '$input' but no such variable in $vars_tf" >&2
      errors=$((errors+1))
    fi
  done

  # HCL variable → expected to be in manifest unless internal/operator-only
  for v in "${hcl_vars[@]}"; do
    # skip explicitly internal contract vars
    skip=false
    for iv in "${INTERNAL_VARS[@]}"; do
      [[ "$v" == "$iv" ]] && { skip=true; break; }
    done
    $skip && continue

    if ! printf '%s\n' "${manifest_inputs[@]}" | grep -qxF "$v"; then
      echo "WARN  [$id]: HCL variable '$v' not in manifest (intentional operator-only knob? If user-facing, add to manifest)" >&2
      warnings=$((warnings+1))
    fi
  done
done

echo
if (( errors > 0 )); then
  echo "FAIL: $errors error(s), $warnings warning(s)"
  exit 1
fi
echo "OK: ${#app_ids[@]} app(s) checked, $warnings warning(s)"
