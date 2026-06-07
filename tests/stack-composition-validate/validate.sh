#!/usr/bin/env bash
# Composition-layer validate. Exercises the four per-layer consumer roots in
# consumer-template/environments/_template/{infra,identity,operations,application}
# against the current working tree — NOT a tagged release.
#
# For each root it sed-rewrites the `?ref=v...` git URL in stack.tf to the local
# platform/ path, runs `terraform init -backend=false + validate`, then reverts
# the rewrite (via git checkout) so the tree is restored even on failure. This
# catches composition bugs (wrong var wiring, bad config→var mapping, for_each
# fan-out) that the per-bundle tests/local-validate fixture can't see.
#
#   ./tests/stack-composition-validate/validate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/consumer-template/environments/_template"
LAYERS=(infra identity operations application)

ROOTS=()
for l in "${LAYERS[@]}"; do ROOTS+=("${TEMPLATE_DIR}/${l}/stack.tf"); done

REWROTE=0
cleanup() {
  cd "$REPO_ROOT"
  [[ "$REWROTE" == "1" ]] && git -C "$REPO_ROOT" checkout -- "${ROOTS[@]}" 2>/dev/null || true
  for l in "${LAYERS[@]}"; do rm -rf "${TEMPLATE_DIR}/${l}/.terraform" "${TEMPLATE_DIR}/${l}/.terraform.lock.hcl"; done
}
trap cleanup EXIT

# Cleanup uses `git checkout`; refuse to clobber uncommitted root edits.
if ! git -C "$REPO_ROOT" diff --quiet -- "${ROOTS[@]}"; then
  echo "ERROR: ${TEMPLATE_DIR}/*/stack.tf has uncommitted changes." >&2
  echo "       Commit or stash before running this fixture (cleanup uses git checkout)." >&2
  exit 2
fi

echo "==> Rewriting ?ref= URLs to local platform/ paths ..."
# git::https://github.com/<owner>/<repo>.git//<path>?ref=v<X.Y.Z>  ->  ../../../../<path>
# (relative to consumer-template/environments/_template/<layer>/)
sed -i.tmp -E \
  's|git::https://github\.com/[^/]+/[^/]+\.git//([^"?]+)\?ref=v[0-9]+\.[0-9]+\.[0-9]+|../../../../\1|g' \
  "${ROOTS[@]}"
rm -f "${ROOTS[@]/%/.tmp}"
REWROTE=1

fail=0
for l in "${LAYERS[@]}"; do
  echo "==> [$l] terraform init + validate ..."
  ( cd "${TEMPLATE_DIR}/${l}" \
      && terraform init -backend=false -upgrade >/dev/null \
      && terraform validate ) || { echo "==> [$l] FAILED"; fail=1; }
done

[[ "$fail" == "0" ]] && echo "==> ok (all four roots valid)"
exit "$fail"
