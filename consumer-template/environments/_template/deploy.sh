#!/usr/bin/env bash
# Deploy this environment: terraform first, ansible second.
#
# Usage:
#   ./deploy.sh                          # full bootstrap + apps
#   ./deploy.sh --skip-tags bootstrap    # fast app-only redeploy
#   ./deploy.sh --tags outline           # one app + its prereqs
#
# Assumes:
#   - sabokit is checked out alongside this consumer repo as a
#     submodule or sibling. Override the path with FED_COMMONS_DIR=...
#   - terraform, ansible-playbook, jq are on PATH
#   - terraform.tfvars and inventory.ini exist (gitignored, per-env)
#   - backend.hcl exists with the per-env bucket/key

set -euo pipefail

ENV_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_NAME="$(basename "$ENV_DIR")"
FED_COMMONS_DIR="${FED_COMMONS_DIR:-${ENV_DIR}/../../../sabokit}"

if [[ ! -d "$FED_COMMONS_DIR/platform/ansible" ]]; then
  echo "ERROR: sabokit not found at $FED_COMMONS_DIR" >&2
  echo "       Set FED_COMMONS_DIR to override, or add sabokit as a submodule." >&2
  exit 1
fi

echo "=== [$ENV_NAME] Terraform: init + apply ==="
terraform -chdir="$ENV_DIR" init -backend-config=backend.hcl
terraform -chdir="$ENV_DIR" apply -auto-approve

echo "=== [$ENV_NAME] Bridging terraform outputs to ansible ==="
terraform -chdir="$ENV_DIR" output -json > "$ENV_DIR/.tf-output.json"
# Reshape into a single dict ansible can consume via -e
jq '{
  enabled_apps:               .enabled_apps.value,
  compute_hosts:              .compute_hosts.value,
  authentik_gateway_domain:   .authentik_gateway_domain.value,
}' "$ENV_DIR/.tf-output.json" > "$ENV_DIR/.ansible-vars.json"

echo "=== [$ENV_NAME] Ansible: site.yml (args: $*) ==="
ANSIBLE_CONFIG="$FED_COMMONS_DIR/platform/ansible/ansible.cfg" \
ansible-playbook "$FED_COMMONS_DIR/platform/ansible/site.yml" \
  -i "$ENV_DIR/inventory.ini" \
  -e @"$ENV_DIR/.ansible-vars.json" \
  -e "environment=$ENV_NAME" \
  "$@"

echo "=== [$ENV_NAME] Done ==="
