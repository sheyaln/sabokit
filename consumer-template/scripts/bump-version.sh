#!/usr/bin/env bash
# Bump every `?ref=...` pinned reference in consumer-template/modules/stack/
# to a new sabokit tag.
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

echo
echo "Done. Run a plan in each environment to see the effect:"
echo "  for env in environments/*/; do"
echo "    [[ -d \"\$env\" && \"\$env\" != */\"_template\"/ ]] || continue"
echo "    (cd \"\$env\" && terraform init -upgrade && terraform plan)"
echo "  done"
