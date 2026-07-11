#!/usr/bin/env bash
# Shared engine for the per-layer deploy scripts. Sourced, never run directly.
#
# The four layer scripts (infra/identity/operations/application.sh) + up.sh/
# down.sh are the runbook made executable. sabokit-cli shells out to these, so
# the scripts are the single source of truth — the CLI only adds UX.
#
# Assumes, when run:
#   - cwd is the consumer repo root (the dir holding environments/ + scripts/).
#   - SCW_ACCESS_KEY / SCW_SECRET_KEY are exported (Scaleway creds).
#   - terraform >= 1.10, ansible-playbook, scw, and jq are on PATH.
#   - sabokit's platform/ansible is reachable through ansible-local/site.yml
#     (the runner image / a sibling sabokit checkout provides it).

set -euo pipefail

ENVIRONMENTS_DIR="environments"

# The blueprint tree. ../sabokit is the sibling-checkout convention; inside
# the runner image it's the baked /workspace/sabokit -> /opt/sabokit symlink.
SABOKIT_TREE="${SABOKIT_TREE:-../sabokit}"

# Ansible plays run from the consumer root (no ansible.cfg there), so point
# ansible at the blueprint's cfg and pin the role search paths absolutely —
# relative roles_path entries don't survive a non-platform/ansible cwd.
if [ -z "${ANSIBLE_CONFIG:-}" ] && [ -f "${SABOKIT_TREE}/platform/ansible/ansible.cfg" ]; then
  export ANSIBLE_CONFIG="${SABOKIT_TREE}/platform/ansible/ansible.cfg"
fi
if [ -z "${ANSIBLE_ROLES_PATH:-}" ]; then
  _p="$(cd "${SABOKIT_TREE}/platform" 2>/dev/null && pwd || true)"
  if [ -n "$_p" ]; then
    export ANSIBLE_ROLES_PATH="${_p}/infra/ansible/roles:${_p}/identity/ansible/roles:$(pwd)/ansible-local/roles"
  fi
  unset _p
fi
export ANSIBLE_HOST_KEY_CHECKING="${ANSIBLE_HOST_KEY_CHECKING:-False}"

log()  { printf '\033[1;34m[sabokit]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[sabokit] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

env_dir()   { echo "${ENVIRONMENTS_DIR}/$1"; }
layer_dir() { echo "${ENVIRONMENTS_DIR}/$1/$2"; }

require_env() {
  [ -n "${1:-}" ] || die "usage: $(basename "${0:-script}") <env>"
  [ -d "$(env_dir "$1")" ] || die "no $(env_dir "$1") — copy environments/_template first"
}

# env_value <env> <key> [default] — read one scalar from the env's env.yml.
env_value() {
  python3 - "$(env_dir "$1")/env.yml" "$2" "${3:-}" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
v = d.get(sys.argv[2])
print(v if v is not None else sys.argv[3])
PY
}

# ── Waits (the slow physics between layers) ──────────────────────────────────
# wait_for <desc> <timeout_s> <interval_s> <probe...> — poll probe until it
# exits 0 or the deadline passes.

wait_for() {
  local desc="$1" timeout="$2" interval="$3"; shift 3
  local deadline=$(( $(date +%s) + timeout ))
  until "$@" >/dev/null 2>&1; do
    [ "$(date +%s)" -lt "$deadline" ] || die "timed out after ${timeout}s waiting for ${desc}"
    sleep "$interval"
  done
}

tcp_open()     { (exec 3<>"/dev/tcp/$1/$2") 2>/dev/null; }
dns_resolves() { getent hosts "$1" >/dev/null 2>&1 || python3 -c 'import socket,sys; socket.gethostbyname(sys.argv[1])' "$1" 2>/dev/null; }
# No -k: this is also the Let's-Encrypt gate — traefik's self-signed
# placeholder cert must NOT pass.
https_200()    { [ "$(curl -sm 10 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null)" = "200" ]; }

# wait_ssh_hosts <env> — block until every infra compute host accepts TCP 22.
wait_ssh_hosts() {
  local env="$1" ip
  for ip in $(tf "$env" infra output -json compute | jq -r '.hosts[].public_ip // empty'); do
    log "waiting for ssh on ${ip}:22"
    wait_for "ssh on ${ip}" 300 5 tcp_open "$ip" 22
  done
}

# Authentik post-boot indexing: the canonical default-* flows + the RBAC
# view_application permission must be queryable before the identity layer's
# terraform (and everything downstream) can plan its data sources.
REQUIRED_FLOWS="default-source-authentication default-source-enrollment default-invalidation-flow default-user-settings-flow default-provider-authorization-implicit-consent default-provider-invalidation-flow"

authentik_indexed() {
  local gw="$1" token="$2" slug n
  for slug in $REQUIRED_FLOWS; do
    n="$(curl -sm 10 -H "Authorization: Bearer ${token}" \
      "https://${gw}/api/v3/flows/instances/?slug=${slug}" | jq -r '.pagination.count // 0')"
    [ "${n:-0}" -ge 1 ] || return 1
  done
  n="$(curl -sm 10 -H "Authorization: Bearer ${token}" \
    "https://${gw}/api/v3/rbac/permissions/?codename=view_application" | jq -r '.pagination.count // 0')"
  [ "${n:-0}" -ge 1 ]
}

# ── Terraform ────────────────────────────────────────────────────────────────

tf() { local env="$1" layer="$2"; shift 2; terraform -chdir="$(layer_dir "$env" "$layer")" "$@"; }

tf_init() {
  local env="$1" layer="$2" d; d="$(layer_dir "$env" "$layer")"
  [ -f "$d/backend.hcl" ] || die "missing $d/backend.hcl (copy backend.hcl.example and fill it)"
  terraform -chdir="$d" init -reconfigure -backend-config=backend.hcl -input=false >&2
}

tf_apply()   { local env="$1" layer="$2"; tf_init "$env" "$layer"; tf "$env" "$layer" apply  -auto-approve -input=false; }
tf_destroy() { local env="$1" layer="$2"; tf_init "$env" "$layer"; tf "$env" "$layer" destroy -auto-approve -input=false; }

# ── Authentik admin token (identity/operations/application providers) ─────────
# infra minted it into a Scaleway secret; fetch api_token, export it.

fetch_authentik_token() {
  local env="$1" sid token
  sid="$(tf "$env" infra output -raw authentik_admin_secret_id 2>/dev/null || true)"
  [ -n "$sid" ] && [ "$sid" != "null" ] || die "infra has no authentik_admin_secret_id — apply infra (with postgres) first"
  sid="${sid##*/}" # strip any region/ prefix
  token="$(scw secret version access "$sid" revision=latest -o json 2>/dev/null \
    | jq -r '.data' | base64 --decode | jq -r '.api_token')"
  [ -n "$token" ] && [ "$token" != "null" ] || die "could not read api_token from secret $sid"
  export TF_VAR_authentik_admin_token="$token"
}

# ── Ansible inventory (from infra's compute output) ──────────────────────────
# Writes environments/<env>/inventory.ini grouping hosts by ansible_group (+
# ansible_groups). Public IPs come straight from terraform.

regen_inventory() {
  local env="$1" inv; inv="$(env_dir "$env")/inventory.ini"
  tf "$env" infra output -json compute | jq -r '
    .hosts as $h
    | ([ $h[] | (.ansible_groups // []) + [.ansible_group] ] | add | unique) as $groups
    | $groups[] as $g
    | "[\($g)]",
      ( $h | to_entries[] | select(((.value.ansible_groups // []) + [.value.ansible_group]) | index($g))
        | "\(.value.name) ansible_host=\(.value.public_ip) ansible_user=ubuntu" ),
      ""
  ' > "$inv"
  printf '[all:vars]\nansible_python_interpreter=/usr/bin/python3\n' >> "$inv"
  log "wrote $inv"
}

# ── enabled_apps (merge whatever layers have been applied) ───────────────────
# Each layer surfaces an enabled_apps/host_services map; the playbooks dispatch
# off the merged object. Null entries (disabled apps) are dropped.

build_enabled_apps() {
  local env="$1" out; out="$(env_dir "$env")/.enabled_apps.json"
  local infra ops app
  infra="$(tf "$env" infra       output -json host_services 2>/dev/null || echo '{}')"
  ops="$(  tf "$env" operations   output -json enabled_apps  2>/dev/null || echo '{}')"
  app="$(  tf "$env" application  output -json enabled_apps  2>/dev/null || echo '{}')"
  # Flatten infra host_services ({svc:{host:inst}}) to enabled_apps keys
  # "<svc>_<host>" so the host-services play dispatches per host.
  jq -n --argjson infra "$infra" --argjson ops "$ops" --argjson app "$app" '
    ($infra | to_entries | map(.key as $svc | (.value | to_entries[]
        | select(.value != null) | { key: "\($svc)_\(.key)", value: .value })) | from_entries) as $hs
    | { enabled_apps: ($hs + $ops + $app | with_entries(select(.value != null))) }
  ' > "$out"
  echo "$out"
}

# ── Monitoring push URLs (config-derived from infra compute IPs) ─────────────
# Alloy on every host remote_writes/pushes to loki+prometheus on the ops host.
# The ops host is where operations.yml deploys loki (deployment_host_key,
# default "management"). Its private IP comes from infra's compute output.

ops_extra_vars() {
  local env="$1" ops_host ip
  ops_host="$(python3 -c 'import sys,yaml
d=yaml.safe_load(open(sys.argv[1])) or {}
print((d.get("loki") or {}).get("deployment_host_key") or (d.get("grafana") or {}).get("deployment_host_key") or "management")' \
    "$(env_dir "$env")/operations.yml" 2>/dev/null || echo management)"
  ip="$(tf "$env" infra output -json compute | jq -r --arg h "$ops_host" '.hosts[$h].private_ip // ""')"
  if [ -n "$ip" ]; then
    echo "-e" "monitoring_loki_push_url=http://${ip}:3100/loki/api/v1/push"
    echo "-e" "monitoring_prometheus_remote_write_url=http://${ip}:9090/api/v1/write"
    # The ops host can't reach its own services via this private IP; the push
    # hairpins back through the host firewall and times out. Every host receives
    # the ops IP and self-detects; the ops host pushes to the co-located
    # containers by name instead (see monitoring-agent role).
    echo "-e" "monitoring_ops_host_ip=${ip}"
  fi
}

# ── Ansible ──────────────────────────────────────────────────────────────────

run_ansible() {
  local env="$1" tags="$2"; shift 2
  local inv ea site; inv="$(env_dir "$env")/inventory.ini"; ea="$(env_dir "$env")/.enabled_apps.json"
  [ -f "$inv" ] || die "no inventory — run regen_inventory first"
  # The consumer wrapper (upstream site.yml + local roles) when it exists,
  # else the blueprint's site.yml straight from the sibling/baked tree.
  if [ -f ansible-local/site.yml ]; then
    site="ansible-local/site.yml"
  elif [ -f "${SABOKIT_TREE}/platform/ansible/site.yml" ]; then
    site="${SABOKIT_TREE}/platform/ansible/site.yml"
  else
    die "no ansible-local/site.yml and no ${SABOKIT_TREE}/platform/ansible/site.yml — checkout sabokit as a sibling or run inside the runner image"
  fi
  log "ansible-playbook ${site} --tags ${tags}"
  ansible-playbook "$site" \
    -i "$inv" \
    -e "@${ea}" \
    -e "env_name=${env}" \
    -e "identity_domain=$(env_value "$env" identity_domain)" \
    --tags "$tags" \
    "$@"
}
