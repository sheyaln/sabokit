#!/usr/bin/env bash
# Composition-layer validate. Sed-rewrites every `?ref=v...` git URL in
# `consumer-template/modules/stack/*.tf` to point at the current working
# tree's local `platform/` paths, then runs `terraform init + validate`.
# Reverts the rewrites at exit so a clean working tree is restored even on
# failure.
#
# Run from this directory:
#   ./validate.sh
#
# Or via repo-root convenience:
#   make stack-composition-validate    # if Makefile target wired
#   ./tests/stack-composition-validate/validate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STACK_DIR="${REPO_ROOT}/consumer-template/modules/stack"

# Files we'll rewrite + restore.
TF_FILES=("${STACK_DIR}"/*.tf)

cleanup() {
  cd "$REPO_ROOT"
  # Restore any rewritten files from git. Safer than maintaining .bak copies
  # — guarantees we're back to the committed shape regardless of script exit.
  git -C "$REPO_ROOT" checkout -- "${STACK_DIR}"/*.tf 2>/dev/null || true
  # Clean the test fixture's .terraform cache so it doesn't pin to local
  # paths across runs.
  rm -rf "${SCRIPT_DIR}/.terraform" "${SCRIPT_DIR}/.terraform.lock.hcl"
}
trap cleanup EXIT

# Refuse to run if consumer-template/modules/stack has uncommitted changes —
# our cleanup uses `git checkout` and would clobber them.
if ! git -C "$REPO_ROOT" diff --quiet -- "${STACK_DIR}"/*.tf; then
  echo "ERROR: ${STACK_DIR}/*.tf has uncommitted changes." >&2
  echo "       Commit or stash before running this fixture (cleanup uses git checkout)." >&2
  exit 2
fi

echo "==> Rewriting ?ref= URLs to local paths in ${STACK_DIR}/*.tf ..."
# Match: git::https://github.com/<owner>/<repo>.git//<path>?ref=v<X>.<Y>.<Z>
# Replace with: ../../<path>  (relative to consumer-template/modules/stack/)
sed -i.tmp -E \
  's|git::https://github\.com/[^/]+/[^/]+\.git//([^"?]+)\?ref=v[0-9]+\.[0-9]+\.[0-9]+|../../../\1|g' \
  "${TF_FILES[@]}"
rm -f "${STACK_DIR}"/*.tf.tmp

echo "==> terraform init ..."
cd "$SCRIPT_DIR"
terraform init -backend=false -upgrade >/dev/null

echo "==> terraform validate ..."
terraform validate

echo "==> ok"
