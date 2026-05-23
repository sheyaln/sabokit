#!/usr/bin/env bash
# Bump every `?ref=...` pinned reference in modules/stack/ to a new
# sabokit tag AND check out the same tag in the sabokit
# git submodule (when present). Leaves the working tree dirty — you commit.
#
# Usage: ./scripts/bump-version.sh v1.1.0

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-tag>"
  exit 1
fi

NEW="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../modules/stack"
SUBMODULE_DIR="${SCRIPT_DIR}/../sabokit"

# Find the current ref. We require all sources to be on the same tag.
CURRENT=$(grep -rEho '\?ref=[^"]+' "${STACK_DIR}" | sort -u)
if [[ "$(echo "$CURRENT" | wc -l)" -ne 1 ]]; then
  echo "ERROR: multiple distinct refs in modules/stack/, refusing to bump:"
  echo "$CURRENT"
  exit 1
fi
OLD="${CURRENT#?ref=}"

if [[ "$OLD" == "$NEW" ]]; then
  echo "Already on $NEW. Nothing to do."
  exit 0
fi

echo "Bumping ${OLD} → ${NEW} across consumer-template/modules/stack/"

case "$(uname)" in
  Darwin) SED_INPLACE=(sed -i '') ;;
  *)      SED_INPLACE=(sed -i) ;;
esac

grep -rl "?ref=${OLD}" "${STACK_DIR}" | while read -r f; do
  "${SED_INPLACE[@]}" "s|?ref=${OLD}|?ref=${NEW}|g" "$f"
  echo "  ${f#"$STACK_DIR"/}"
done

# If sabokit is a git submodule (or a plain checkout) at the
# canonical path, move it to the same tag. Without this the consumer's
# Ansible roles (loaded from $SUBMODULE_DIR/platform/...) would still
# point at the previous version while terraform now resolves the new tag —
# easy way to ship a half-bumped env.
if [[ -d "$SUBMODULE_DIR/.git" || -f "$SUBMODULE_DIR/.git" ]]; then
  echo
  echo "Bumping sabokit submodule to ${NEW}"
  (
    cd "$SUBMODULE_DIR"
    git fetch --quiet --tags origin
    git checkout --quiet "$NEW"
  )
  echo "  sabokit → $(cd "$SUBMODULE_DIR" && git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)"
elif [[ -d "$SUBMODULE_DIR" ]]; then
  echo
  echo "WARN: $SUBMODULE_DIR exists but isn't a git checkout. Skipped submodule bump."
else
  echo
  echo "(No sabokit checkout at $SUBMODULE_DIR — only ?ref= pins bumped.)"
fi

echo
echo "Done. Inspect with:"
echo "  git status"
echo "Then plan per env:"
echo "  for env in environments/*/; do"
echo "    [[ -d \"\$env\" && \"\$env\" != */\"_template\"/ ]] || continue"
echo "    (cd \"\$env\" && terraform init -upgrade && terraform plan)"
echo "  done"
