#!/usr/bin/env bash
# Sync the sabokit version pin. The source of truth is
#   environments/common.yml -> `sabokit_version:`
# This script propagates that value into every per-layer root's module source
# (the `?ref=` in environments/*/*/stack.tf). Terraform requires a module
# `source` to be a static string literal, so it cannot read the pin from YAML
# directly; this script is the bridge that keeps the literals == common.yml.
#
# It also checks out the same tag in the sabokit checkout (when present, for the
# Ansible roles). Leaves the working tree dirty — you commit.
#
# Usage:
#   ./scripts/bump-version.sh v1.1.0   # set common.yml AND sync every stack.tf
#   ./scripts/bump-version.sh          # read common.yml, sync every stack.tf

set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [<new-tag>]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/../environments"
COMMON_YML="${ENV_DIR}/common.yml"
SABOKIT_DIR="${SCRIPT_DIR}/../sabokit"

[[ -f "$COMMON_YML" ]] || { echo "ERROR: $COMMON_YML not found"; exit 1; }

case "$(uname)" in
  Darwin) SED_INPLACE=(sed -i '') ;;
  *)      SED_INPLACE=(sed -i) ;;
esac

read_pin() { # the sabokit_version value from common.yml, or empty
  sed -nE 's/^[[:space:]]*sabokit_version:[[:space:]]*"?([^"#[:space:]]+)"?.*/\1/p' "$COMMON_YML" | head -1
}

# Optional arg sets the pin in common.yml (the source of truth).
if [[ $# -eq 1 ]]; then
  NEW="$1"
  if [[ ! "$NEW" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
    echo "ERROR: tag must look like vX.Y.Z or vX.Y.Z-suffix (got: $NEW)"
    exit 1
  fi
  if grep -qE '^[[:space:]]*sabokit_version:' "$COMMON_YML"; then
    "${SED_INPLACE[@]}" -E "s|^([[:space:]]*sabokit_version:[[:space:]]*).*|\1${NEW}|" "$COMMON_YML"
  else
    printf '\nsabokit_version: %s\n' "$NEW" >> "$COMMON_YML"
  fi
  echo "Set sabokit_version: ${NEW} in ${COMMON_YML#"$ENV_DIR"/}"
fi

PIN="$(read_pin)"
[[ -n "$PIN" ]] || { echo "ERROR: no sabokit_version in $COMMON_YML (pass a tag to set it)"; exit 1; }

# Every per-layer root's stack.tf (environments/<env>/<layer>/stack.tf),
# including the _template so it stays current.
REF_FILES=()
while IFS= read -r f; do REF_FILES+=("$f"); done \
  < <(find "$ENV_DIR" -mindepth 3 -maxdepth 3 -name stack.tf 2>/dev/null | sort)
if [[ ${#REF_FILES[@]} -eq 0 ]]; then
  echo "ERROR: no environments/*/*/stack.tf found under $ENV_DIR"
  exit 1
fi

echo "Syncing ?ref= -> ${PIN} across environments/*/*/stack.tf:"
changed=0
for f in "${REF_FILES[@]}"; do
  grep -qE '\?ref=' "$f" || continue
  before="$(grep -oE '\?ref=[a-zA-Z0-9._-]+' "$f" | sort -u)"
  "${SED_INPLACE[@]}" -E "s|(\?ref=)[a-zA-Z0-9._-]+|\1${PIN}|g" "$f"
  after="$(grep -oE '\?ref=[a-zA-Z0-9._-]+' "$f" | sort -u)"
  if [[ "$before" != "$after" ]]; then
    echo "  ${f#"$ENV_DIR"/}"
    changed=$((changed + 1))
  fi
done
[[ $changed -eq 0 ]] && echo "  (already in sync)"

# Verify every ref now equals the pin.
STRAY="$(grep -rhoE '\?ref=[a-zA-Z0-9._-]+' "${REF_FILES[@]}" | sort -u | grep -vxF "?ref=${PIN}" || true)"
if [[ -n "$STRAY" ]]; then
  echo "ERROR: refs still diverge from ${PIN} after sync:"
  echo "$STRAY"
  exit 1
fi

# Keep the sabokit Ansible roles in lockstep with the terraform pin. Without
# this the consumer's deploy loads roles from $SABOKIT_DIR/platform/... at the
# previous version while terraform resolves the pinned tag — a half-bumped env.
if [[ -d "$SABOKIT_DIR/.git" || -f "$SABOKIT_DIR/.git" ]]; then
  echo
  echo "Bumping sabokit checkout to ${PIN}"
  (
    cd "$SABOKIT_DIR"
    git fetch --quiet --tags origin
    git checkout --quiet "$PIN"
  )
  echo "  sabokit → $(cd "$SABOKIT_DIR" && git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)"
elif [[ -d "$SABOKIT_DIR" ]]; then
  echo
  echo "WARN: $SABOKIT_DIR exists but isn't a git checkout. Skipped roles bump."
else
  echo
  echo "(No sabokit checkout at $SABOKIT_DIR — only common.yml + ?ref= pins synced.)"
fi

echo
echo "Done. Source of truth is ${COMMON_YML#"$ENV_DIR"/} (sabokit_version: ${PIN})."
echo "Inspect with: git status"
