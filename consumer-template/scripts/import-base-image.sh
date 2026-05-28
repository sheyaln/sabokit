#!/usr/bin/env bash
# Import the sabokit pre-baked base image into the consumer's
# Scaleway project. Run once per release tag.
#
# What it does:
#   1. Downloads fc-base-<TAG>.qcow2 from the sabokit GitHub Release.
#   2. Uploads it to a temporary bucket in the consumer's Scaleway Object Storage.
#   3. Imports the object as a Scaleway block snapshot.
#   4. Registers the snapshot as a Scaleway instance image.
#   5. Prints the resulting image_id — paste it into config.tf under
#      locals.config.compute_hosts.<name>.image.
#
# Prerequisites:
#   - scw CLI configured (run `scw init` if not — the SCW_ACCESS_KEY /
#     SCW_SECRET_KEY / SCW_DEFAULT_PROJECT_ID / SCW_DEFAULT_REGION env vars
#     also work).
#   - aws CLI installed and configured for Scaleway Object Storage (alias
#     `~/.aws/config` is the easiest, but env vars work too).
#   - curl, jq.
#
# Usage:
#   ./import-base-image.sh v1.4.0
#
# Idempotent in the sense that re-running with the same tag uploads the qcow2
# again and creates a *new* snapshot + image (Scaleway has no upsert). Delete
# the stale image manually if you want to reclaim its storage.

set -euo pipefail

REPO_SLUG="${FC_REPO_SLUG:-sheyaln/sabokit}"
REGION="${SCW_DEFAULT_REGION:-fr-par}"
ZONE="${SCW_DEFAULT_ZONE:-${REGION}-1}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <release-tag>   (e.g. v1.4.0)"
  exit 2
fi

TAG="$1"
VERSION="${TAG#v}"
QCOW="fc-base-${TAG}.qcow2"
RELEASE_URL="https://github.com/${REPO_SLUG}/releases/download/${TAG}/${QCOW}"
BUCKET="${FC_IMPORT_BUCKET:-fc-base-import-$(date -u +%Y%m%d%H%M%S)}"
SNAPSHOT_NAME="fc-base-${VERSION}-imported"
IMAGE_NAME="fc-base-${VERSION}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

c_ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
c_info() { printf "  → %s\n" "$*"; }
c_err()  { printf "  \033[31m✗\033[0m %s\n" "$*"; }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    c_err "missing required command: $1"
    exit 1
  }
}

section "Preflight"
require_cmd curl
require_cmd jq
require_cmd scw
require_cmd aws
c_ok "all required CLIs present"

if ! scw config get default-project-id >/dev/null 2>&1 && [[ -z "${SCW_DEFAULT_PROJECT_ID:-}" ]]; then
  c_err "Scaleway CLI not configured. Run \`scw init\` or export SCW_ACCESS_KEY/SCW_SECRET_KEY/SCW_DEFAULT_PROJECT_ID."
  exit 1
fi
c_ok "scw CLI configured"

section "Download release asset"
c_info "URL: ${RELEASE_URL}"
curl -fL --retry 3 --progress-bar -o "${WORKDIR}/${QCOW}" "${RELEASE_URL}"
SIZE_BYTES="$(stat -c%s "${WORKDIR}/${QCOW}" 2>/dev/null || stat -f%z "${WORKDIR}/${QCOW}")"
c_ok "downloaded ${QCOW} (${SIZE_BYTES} bytes)"

section "Create temporary import bucket"
ENDPOINT="https://s3.${REGION}.scw.cloud"
aws --endpoint-url "${ENDPOINT}" s3 mb "s3://${BUCKET}" \
  --region "${REGION}"
c_ok "bucket ${BUCKET} created in ${REGION}"

section "Upload qcow2 to object storage"
aws --endpoint-url "${ENDPOINT}" s3 cp \
  "${WORKDIR}/${QCOW}" \
  "s3://${BUCKET}/${QCOW}" \
  --region "${REGION}"
c_ok "uploaded s3://${BUCKET}/${QCOW}"

section "Import snapshot from object storage"
SNAPSHOT_JSON="$(scw block snapshot import-from-object-storage \
  bucket="${BUCKET}" \
  key="${QCOW}" \
  name="${SNAPSHOT_NAME}" \
  zone="${ZONE}" \
  -o json)"
SNAPSHOT_ID="$(echo "${SNAPSHOT_JSON}" | jq -r '.id')"
c_ok "snapshot import started: ${SNAPSHOT_ID}"

c_info "waiting for snapshot to reach status=available (this can take several minutes)…"
for _ in $(seq 1 120); do
  STATUS="$(scw block snapshot get "${SNAPSHOT_ID}" zone="${ZONE}" -o json | jq -r '.status')"
  case "${STATUS}" in
    available) c_ok "snapshot available"; break ;;
    error)     c_err "snapshot import failed"; exit 1 ;;
    *)         sleep 10 ;;
  esac
done
if [[ "${STATUS:-}" != "available" ]]; then
  c_err "snapshot did not become available in time (last status: ${STATUS:-unknown})"
  exit 1
fi

section "Register image from snapshot"
IMAGE_JSON="$(scw instance image create \
  name="${IMAGE_NAME}" \
  snapshot-id="${SNAPSHOT_ID}" \
  arch=x86_64 \
  zone="${ZONE}" \
  -o json)"
IMAGE_ID="$(echo "${IMAGE_JSON}" | jq -r '.id')"
c_ok "image registered: ${IMAGE_ID}"

section "Clean up temporary bucket"
aws --endpoint-url "${ENDPOINT}" s3 rm "s3://${BUCKET}/${QCOW}" --region "${REGION}" || true
aws --endpoint-url "${ENDPOINT}" s3 rb "s3://${BUCKET}" --region "${REGION}" || true
c_ok "bucket removed"

section "Done"
echo
echo "Paste this into config.tf under locals.config.compute_hosts.<name>.image:"
echo
echo "  image = \"${IMAGE_ID}\""
echo
echo "Or, if you want to share the value across hosts:"
echo
echo "  locals { fc_base_image = \"${IMAGE_ID}\" }"
echo
