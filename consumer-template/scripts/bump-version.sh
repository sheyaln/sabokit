#!/usr/bin/env bash
# Bump every `?ref=...` pinned reference in consumer-template/terraform/ to
# a new sabokit tag.
#
# Usage: ./scripts/bump-version.sh v1.1.0

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-tag>"
  exit 1
fi

NEW="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform"

# Find the current ref. We require all sources to be on the same tag.
CURRENT=$(grep -rEho '\?ref=[^"]+' "${TF_DIR}" | sort -u)
if [[ "$(echo "$CURRENT" | wc -l)" -ne 1 ]]; then
  echo "ERROR: multiple distinct refs in terraform/, refusing to bump:"
  echo "$CURRENT"
  exit 1
fi
OLD="${CURRENT#?ref=}"

if [[ "$OLD" == "$NEW" ]]; then
  echo "Already on $NEW. Nothing to do."
  exit 0
fi

echo "Bumping ${OLD} → ${NEW} across consumer-template/terraform/"

case "$(uname)" in
  Darwin) SED_INPLACE=(sed -i '') ;;
  *)      SED_INPLACE=(sed -i) ;;
esac

grep -rl "?ref=${OLD}" "${TF_DIR}" | while read -r f; do
  "${SED_INPLACE[@]}" "s|?ref=${OLD}|?ref=${NEW}|g" "$f"
  echo "  ${f#"$TF_DIR"/}"
done

echo
echo "Done. Run:"
echo "  cd ${TF_DIR} && terraform init -upgrade && terraform plan"
