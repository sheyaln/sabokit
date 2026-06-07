#!/usr/bin/env bash
# Bump every `?ref=...` pin in environments/*/*/stack.tf (every env's per-layer
# roots) to a new sabokit tag, AND check out the same tag in the sabokit
# checkout (when present, for the Ansible roles). Leaves the working tree dirty
# — you commit.
#
# Usage: ./scripts/bump-version.sh v1.1.0

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-tag>"
  exit 1
fi

NEW="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/../environments"
SABOKIT_DIR="${SCRIPT_DIR}/../sabokit"

# Every per-layer root's stack.tf (environments/<env>/<layer>/stack.tf),
# including the _template so it stays current.
REF_FILES=()
while IFS= read -r f; do REF_FILES+=("$f"); done \
  < <(find "$ENV_DIR" -mindepth 3 -maxdepth 3 -name stack.tf 2>/dev/null | sort)
if [[ ${#REF_FILES[@]} -eq 0 ]]; then
  echo "ERROR: no environments/*/*/stack.tf found under $ENV_DIR"
  exit 1
fi

# Require all roots on the same tag before bumping.
CURRENT=$(grep -rEho '\?ref=[^"]+' "${REF_FILES[@]}" | sort -u)
if [[ "$(echo "$CURRENT" | wc -l)" -ne 1 ]]; then
  echo "ERROR: multiple distinct refs across environments/*/*/stack.tf, refusing to bump:"
  echo "$CURRENT"
  exit 1
fi
OLD="${CURRENT#?ref=}"

if [[ "$OLD" == "$NEW" ]]; then
  echo "Already on $NEW. Nothing to do."
  exit 0
fi

echo "Bumping ${OLD} → ${NEW} across environments/*/*/stack.tf"

case "$(uname)" in
  Darwin) SED_INPLACE=(sed -i '') ;;
  *)      SED_INPLACE=(sed -i) ;;
esac

grep -rl "?ref=${OLD}" "${REF_FILES[@]}" | while read -r f; do
  "${SED_INPLACE[@]}" "s|?ref=${OLD}|?ref=${NEW}|g" "$f"
  echo "  ${f#"$ENV_DIR"/}"
done

# Keep the sabokit Ansible roles in lockstep with the terraform pin. Without
# this the consumer's deploy loads roles from $SABOKIT_DIR/platform/... at the
# previous version while terraform resolves the new tag — a half-bumped env.
if [[ -d "$SABOKIT_DIR/.git" || -f "$SABOKIT_DIR/.git" ]]; then
  echo
  echo "Bumping sabokit checkout to ${NEW}"
  (
    cd "$SABOKIT_DIR"
    git fetch --quiet --tags origin
    git checkout --quiet "$NEW"
  )
  echo "  sabokit → $(cd "$SABOKIT_DIR" && git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)"
elif [[ -d "$SABOKIT_DIR" ]]; then
  echo
  echo "WARN: $SABOKIT_DIR exists but isn't a git checkout. Skipped roles bump."
else
  echo
  echo "(No sabokit checkout at $SABOKIT_DIR — only ?ref= pins bumped.)"
fi

echo
echo "Done. Inspect with: git status"
echo "Then re-init + plan each layer of each env, e.g.:"
echo "  for env in environments/*/; do"
echo "    [[ -d \"\$env\" && \"\$(basename \"\$env\")\" != _template ]] || continue"
echo "    for layer in infra identity operations application; do"
echo "      terraform -chdir=\"\${env}\${layer}\" init -upgrade -backend-config=backend.hcl && \\"
echo "      terraform -chdir=\"\${env}\${layer}\" plan"
echo "    done"
echo "  done"
