#!/usr/bin/env bash
# Bump every `?ref=...` pin in consumer-template/modules/stack/ to a new
# tag, commit the ref-bump as a chore commit, tag the commit, and push
# master + the tag. One-shot replacement for the manual perl + git tag +
# push dance.
#
# Pre-conditions:
#   - master is clean (no uncommitted changes except the WIP allowlist
#     below — policy templates that have been WIP all session).
#   - The CHANGELOG.md entry for <new-tag> already exists.
#   - All feature work for <new-tag> is already committed on master.
#
# This script does NOT:
#   - write the CHANGELOG (release author writes it as part of the feature work)
#   - run terraform validate (already part of pre-merge subagent contract)
#   - touch consumer-template/scripts/bump-version.sh (that's the consumer's tool)
#
# Usage:
#   ./scripts/release.sh v2.15.2

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-tag>"
  echo "Example: $0 v2.15.2"
  exit 1
fi

NEW="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_DIR="${REPO_ROOT}/consumer-template/modules/stack"

if [[ ! "$NEW" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: tag must look like vX.Y.Z (got: $NEW)"
  exit 1
fi

cd "$REPO_ROOT"

# Confirm master.
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "master" ]]; then
  echo "ERROR: must run from master (currently on $CURRENT_BRANCH)"
  exit 1
fi

# Confirm tag doesn't already exist.
if git rev-parse "$NEW" >/dev/null 2>&1; then
  echo "ERROR: tag $NEW already exists. Delete it first if intentional."
  exit 1
fi

# Confirm CHANGELOG has the entry.
if ! grep -q "^## ${NEW} " "${REPO_ROOT}/CHANGELOG.md"; then
  echo "ERROR: CHANGELOG.md has no entry for $NEW"
  echo "Add a '## $NEW — <title>' section before releasing."
  exit 1
fi

# Find every ?ref= currently in consumer-template/modules/stack/.
# Multiple distinct refs is fine — each gets bumped independently. The
# common case is one per file family (base.tf, identity.tf, identity_bootstrap.tf,
# apps.tf can each pin different tags depending on how recently each layer
# shipped).
declare -A REF_COUNTS
while IFS= read -r ref; do
  REF_COUNTS["$ref"]=$((${REF_COUNTS[$ref]:-0} + 1))
done < <(grep -rEho '\?ref=[^"]+' "${STACK_DIR}" | sort -u | sed 's/^?ref=//')

if [[ ${#REF_COUNTS[@]} -eq 0 ]]; then
  echo "ERROR: no ?ref= pins found in $STACK_DIR. Wrong dir?"
  exit 1
fi

echo "Bumping consumer-template/modules/stack/ refs to $NEW:"
case "$(uname)" in
  Darwin) SED_INPLACE=(sed -i '') ;;
  *)      SED_INPLACE=(sed -i) ;;
esac

for OLD in "${!REF_COUNTS[@]}"; do
  if [[ "$OLD" == "$NEW" ]]; then
    echo "  $OLD: already on $NEW (skipped)"
    continue
  fi
  while IFS= read -r f; do
    "${SED_INPLACE[@]}" "s|?ref=${OLD}|?ref=${NEW}|g" "$f"
  done < <(grep -rl "?ref=${OLD}" "${STACK_DIR}")
  echo "  $OLD → $NEW (${REF_COUNTS[$OLD]} pin(s))"
done

# Verify the bump landed.
RESIDUAL=$(grep -rEho '\?ref=[^"]+' "${STACK_DIR}" | sort -u | grep -v "?ref=${NEW}" || true)
if [[ -n "$RESIDUAL" ]]; then
  echo "ERROR: residual non-$NEW refs after bump:"
  echo "$RESIDUAL"
  exit 1
fi

# Stage only the consumer-template changes.
git add "${STACK_DIR}"

# Detect if there's anything to commit (no-op if already on $NEW everywhere).
if git diff --cached --quiet; then
  echo "No ref changes to commit (everything was already on $NEW)."
else
  git commit -m "chore(consumer-template): bump refs to $NEW"
fi

# Tag the current master tip.
echo "Tagging $NEW..."
git tag -a "$NEW" -m "$(grep -m1 "^## ${NEW} " "${REPO_ROOT}/CHANGELOG.md" | sed "s/^## //")"

echo "Pushing master + $NEW..."
git push origin master
git push origin "$NEW"

echo
echo "Released $NEW."
echo "Next: send the peer/consumer notification + close any open tasks."
