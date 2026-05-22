#!/usr/bin/env bash
# Deploy this environment end-to-end. Run preflight.sh first.
#
# Phases (re-running is idempotent — each phase is safe to skip on a fresh run
# AND on a partial-failure recovery):
#
#   1. terraform apply (base + identity_bootstrap)
#         → VPC, hosts, postgres, secrets (incl. pre-generated admin api_token).
#
#   2. Inventory regen + SSH reachability
#         → rewrite inventory.ini from compute_hosts output, clear stale host
#           keys, wait for SSH on every host.
#
#   3. ansible-playbook bootstrap.yml
#         → docker, traefik, scw-secrets, monitoring-agent on every host,
#           plus authentik-server on the [identity] host. The role wires
#           AUTHENTIK_BOOTSTRAP_TOKEN from the pre-generated secret so
#           Authentik creates the matching API Token on first boot.
#
#   4. Wait for Let's Encrypt to mint the gateway cert.
#         → polls https://${gateway_domain}/api/v3/root/config/; forces a
#           Traefik restart after 60s if the cert hasn't materialized.
#
#   5. terraform apply (full)
#         → identity bundle configures the running Authentik (flows, brand,
#           groups, outpost) plus every enabled app's terraform.
#
#   6. ansible-playbook apps.yml
#         → deploys every enabled app's container stack.
#
#   7. Smoke tests
#         → each enabled app's URL should redirect to Authentik.
#
# Flags forwarded to ansible-playbook (after --):
#   ./deploy.sh -- --skip-tags bootstrap      # fast app-only redeploy
#   ./deploy.sh -- --tags outline             # one app + its prereqs
#
# Other env vars:
#   FED_COMMONS_DIR    override path to sabokit (default:
#                      ../../../sabokit relative to this script)
#   SKIP_PHASE         comma-separated list of phase numbers to skip
#                      (e.g. SKIP_PHASE=4,7 ./deploy.sh — rare; debugging only)

set -euo pipefail

# ── Setup ───────────────────────────────────────────────────────────────────

ENV_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_NAME="$(basename "$ENV_DIR")"
FED_COMMONS_DIR="${FED_COMMONS_DIR:-${ENV_DIR}/../../../sabokit}"
SKIP_PHASE="${SKIP_PHASE:-}"

ANSIBLE_ARGS=()
if [[ "${1:-}" == "--" ]]; then
  shift
  ANSIBLE_ARGS=("$@")
fi

if [[ ! -d "$FED_COMMONS_DIR/platform/ansible" ]]; then
  echo "ERROR: sabokit not found at $FED_COMMONS_DIR" >&2
  echo "       Set FED_COMMONS_DIR to override, or add sabokit as a submodule." >&2
  exit 1
fi

cd "$ENV_DIR"

# ── Pretty output ───────────────────────────────────────────────────────────

c_phase() { printf "\n\033[1;36m=== Phase %s: %s ===\033[0m\n" "$1" "$2"; }
c_ok()    { printf "  \033[32m✓\033[0m %s\n" "$*"; }
c_warn()  { printf "  \033[33m!\033[0m %s\n" "$*"; }
c_err()   { printf "  \033[31m✗\033[0m %s\n" "$*"; }
c_info()  { printf "  → %s\n" "$*"; }

skip_phase() {
  [[ ",$SKIP_PHASE," == *",$1,"* ]]
}

tfvar() {
  awk -v key="$1" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, ""); gsub(/^"|"[[:space:]]*$/, "")
      sub(/[[:space:]]*#.*$/, ""); print; exit
    }
  ' terraform.tfvars
}

# ── Sanity ──────────────────────────────────────────────────────────────────

[[ -f terraform.tfvars ]] || { echo "ERROR: terraform.tfvars missing — run ./preflight.sh first." >&2; exit 1; }
[[ -f backend.hcl      ]] || { echo "ERROR: backend.hcl missing — see backend.hcl.example."     >&2; exit 1; }

GATEWAY_DOMAIN="$(tfvar gateway_domain || true)"
SCW_PROJECT_ID="$(tfvar scaleway_project_id || true)"
[[ -n "$GATEWAY_DOMAIN"  ]] || { echo "ERROR: gateway_domain not set in terraform.tfvars."  >&2; exit 1; }
[[ -n "$SCW_PROJECT_ID"  ]] || { echo "ERROR: scaleway_project_id not set in terraform.tfvars." >&2; exit 1; }

# Always init — cheap when the state directory is warm, recovers from a fresh
# clone otherwise.
terraform init -backend-config=backend.hcl -input=false >/dev/null

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1 — base + identity bootstrap
# ─────────────────────────────────────────────────────────────────────────────

if ! skip_phase 1; then
  c_phase 1 "Terraform apply (base + identity bootstrap)"
  terraform apply \
    -target=module.stack.module.base \
    -target=module.stack.module.identity_bootstrap \
    -auto-approve \
    -input=false
  c_ok "Base + identity_bootstrap applied"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2 — inventory regen, host-key reset, SSH wait
# ─────────────────────────────────────────────────────────────────────────────

terraform output -json > .tf-output.json

if ! skip_phase 2; then
  c_phase 2 "Inventory + SSH reachability"

  # Rebuild inventory.ini from terraform output. Each host_key becomes a host
  # named "<host_key>-<env>" with public_ip, grouped under its ansible_group.
  python3 - <<'PYEOF' .tf-output.json "$ENV_NAME" > inventory.ini
import json, sys, collections
data = json.load(open(sys.argv[1]))
env = sys.argv[2]
hosts = data["compute_hosts"]["value"]
by_group = collections.defaultdict(list)
for short, h in hosts.items():
    by_group[h["ansible_group"]].append(
        f'{short}-{env} ansible_host={h["public_ip"]} ansible_user=ubuntu'
    )
out = []
for group in sorted(by_group):
    out.append(f"[{group}]")
    out.extend(by_group[group])
    out.append("")
out.append("[all:vars]")
out.append("ansible_python_interpreter=/usr/bin/python3")
print("\n".join(out))
PYEOF
  c_ok "Wrote inventory.ini"

  # Collect IPs for the next two checks.
  IPS=($(jq -r '.compute_hosts.value | to_entries[] | .value.public_ip' .tf-output.json))

  # Clear stale known_hosts entries (host key drift across re-creates).
  for ip in "${IPS[@]}"; do
    ssh-keygen -R "$ip" >/dev/null 2>&1 || true
  done
  c_ok "Cleared known_hosts entries for new IPs"

  # Wait for SSH on every host (up to 5min each).
  for ip in "${IPS[@]}"; do
    c_info "Waiting for SSH on $ip ..."
    for attempt in $(seq 1 60); do
      if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
              -o BatchMode=yes -o LogLevel=ERROR \
              "ubuntu@$ip" 'true' 2>/dev/null; then
        c_ok "$ip reachable"
        break
      fi
      if [[ $attempt -eq 60 ]]; then
        c_err "$ip not reachable after 5 minutes"
        exit 1
      fi
      sleep 5
    done
  done
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3 — Ansible bootstrap (docker / traefik / authentik server / ...)
# ─────────────────────────────────────────────────────────────────────────────

# Build ansible-vars.json fresh each run; bootstrap.yml + apps.yml both read it.
jq '{
  enabled_apps:               .enabled_apps.value,
  compute_hosts:              .compute_hosts.value,
  authentik_gateway_domain:   .authentik_gateway_domain.value,
  identity_bootstrap:         .identity_bootstrap.value,
  traefik_acme_email:         .infra_email.value,
}' .tf-output.json > .ansible-vars.json

if ! skip_phase 3; then
  c_phase 3 "Ansible bootstrap (docker, traefik, authentik-server)"
  ANSIBLE_CONFIG="$FED_COMMONS_DIR/platform/ansible/ansible.cfg" \
  ansible-playbook "$FED_COMMONS_DIR/platform/ansible/bootstrap.yml" \
    -i inventory.ini \
    -e @.ansible-vars.json \
    -e "env_name=$ENV_NAME" \
    -e "gateway_domain=$GATEWAY_DOMAIN" \
    -e "scaleway_project_id=$SCW_PROJECT_ID" \
    "${ANSIBLE_ARGS[@]}"
  c_ok "Bootstrap complete"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4 — Wait for Traefik LE cert
# ─────────────────────────────────────────────────────────────────────────────

if ! skip_phase 4; then
  c_phase 4 "Waiting for Let's Encrypt cert on $GATEWAY_DOMAIN"
  IDENTITY_HOST="$(awk '/^\[identity\]/{flag=1; next} /^\[/{flag=0} flag && NF {print $2; exit}' inventory.ini | cut -d= -f2)"
  cert_ok=false
  for attempt in $(seq 1 24); do
    if curl -sfo /dev/null --max-time 10 "https://${GATEWAY_DOMAIN}/api/v3/root/config/"; then
      cert_ok=true
      break
    fi
    if [[ $attempt -eq 6 && -n "$IDENTITY_HOST" ]]; then
      c_warn "LE cert not yet valid after 60s — forcing Traefik restart"
      ssh -o BatchMode=yes "ubuntu@${IDENTITY_HOST}" 'sudo docker compose -f /opt/traefik/docker-compose.yml restart traefik' || true
    fi
    sleep 10
  done
  if $cert_ok; then
    c_ok "TLS reachable at https://${GATEWAY_DOMAIN}"
  else
    c_err "Gateway not reachable after 4 minutes. Check Traefik logs:"
    c_info "  ssh ubuntu@${IDENTITY_HOST:-<identity-host>} 'sudo docker logs traefik --tail=100'"
    exit 1
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5 — fetch API token, full terraform apply
# ─────────────────────────────────────────────────────────────────────────────

if ! skip_phase 5; then
  c_phase 5 "Terraform apply (identity + apps)"

  ADMIN_SECRET_ID="$(jq -r '.authentik_admin_secret_id.value' .tf-output.json)"
  [[ -n "$ADMIN_SECRET_ID" && "$ADMIN_SECRET_ID" != "null" ]] || {
    c_err "authentik_admin_secret_id not in terraform output. Phase 1 didn't apply identity_bootstrap?"
    exit 1
  }
  # Scaleway returns the bare UUID after stripping the region/ prefix.
  ADMIN_SECRET_UUID="${ADMIN_SECRET_ID##*/}"
  ADMIN_TOKEN="$(scw secret version access secret-id="$ADMIN_SECRET_UUID" revision=latest -o json \
                  | jq -r '.data' | base64 -d | jq -r '.api_token')"
  [[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "null" ]] || {
    c_err "Couldn't read api_token from the admin secret. Did Phase 1 generate it?"
    exit 1
  }
  c_ok "Fetched admin API token from Scaleway Secret Manager"

  TF_VAR_authentik_admin_token="$ADMIN_TOKEN" \
    terraform apply -auto-approve -input=false
  c_ok "Full terraform apply complete"

  # Refresh .ansible-vars.json — module outputs may have changed.
  terraform output -json > .tf-output.json
  jq '{
    enabled_apps:               .enabled_apps.value,
    compute_hosts:              .compute_hosts.value,
    authentik_gateway_domain:   .authentik_gateway_domain.value,
    identity_bootstrap:         .identity_bootstrap.value,
  }' .tf-output.json > .ansible-vars.json
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 6 — Ansible apps deploy
# ─────────────────────────────────────────────────────────────────────────────

if ! skip_phase 6; then
  c_phase 6 "Ansible apps deploy"
  ANSIBLE_CONFIG="$FED_COMMONS_DIR/platform/ansible/ansible.cfg" \
  ansible-playbook "$FED_COMMONS_DIR/platform/ansible/apps.yml" \
    -i inventory.ini \
    -e @.ansible-vars.json \
    -e "env_name=$ENV_NAME" \
    -e "gateway_domain=$GATEWAY_DOMAIN" \
    "${ANSIBLE_ARGS[@]}"
  c_ok "Apps deployed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 7 — Smoke tests
# ─────────────────────────────────────────────────────────────────────────────

if ! skip_phase 7; then
  c_phase 7 "Smoke tests"
  APP_URLS=($(jq -r '.enabled_apps.value | to_entries[] | select(.value != null) | .value.url' .tf-output.json))
  if [[ ${#APP_URLS[@]} -eq 0 ]]; then
    c_info "No apps enabled — nothing to smoke-test."
  else
    fail=0
    for url in "${APP_URLS[@]}"; do
      code="$(curl -sfo /dev/null -w '%{http_code}' --max-time 15 "$url" || true)"
      # Authentik forward-auth redirects unauthenticated requests with 302/303.
      # Outline & similar OIDC apps return 302/303 to /auth/.
      if [[ "$code" =~ ^(2|3)[0-9][0-9]$ ]]; then
        c_ok "$url → HTTP $code"
      else
        c_err "$url → HTTP $code (expected 2xx/3xx)"
        fail=$((fail+1))
      fi
    done
    [[ $fail -eq 0 ]] || { c_err "$fail app(s) failed smoke test."; exit 1; }
  fi
fi

c_phase Done "Deployment complete"
c_info "Gateway: https://${GATEWAY_DOMAIN}"
c_info "Re-run anytime — every phase is idempotent."
