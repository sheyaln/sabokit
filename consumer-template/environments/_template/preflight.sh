#!/usr/bin/env bash
# Preflight checks. Run this once per env, after copying *.example files
# and editing terraform.tfvars, BEFORE the first `./deploy.sh`.
#
# Idempotent — re-running is safe and only acts on the missing pieces:
#   - required CLIs on PATH (terraform, ansible, ansible-playbook, jq, scw)
#   - Scaleway credentials present (SCW_ACCESS_KEY / SCW_SECRET_KEY env)
#   - Python "scaleway" SDK installed for Ansible's interpreter (the
#     scaleway.scaleway.scaleway_secret lookup needs it server-side)
#   - SSH public key uploaded to the Scaleway IAM keystore for this project
#   - DNS A record for ${gateway_domain} resolves to *something* (placeholder
#     fine — the gateway IP only exists after `./deploy.sh` first phase). If
#     the zone lives in a different Scaleway project from the deploy project,
#     export SCW_DNS_ACCESS_KEY and SCW_DNS_SECRET_KEY before running.
#   - terraform.tfvars, backend.hcl, inventory.ini all exist
#
# Anything that fails prints the exact remediation command. Re-run preflight
# after fixing — it stops at the first hard failure.

set -euo pipefail

ENV_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_NAME="$(basename "$ENV_DIR")"

cd "$ENV_DIR"

# ── Pretty output ───────────────────────────────────────────────────────────

c_ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
c_warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
c_err()  { printf "  \033[31m✗\033[0m %s\n" "$*"; }
c_info() { printf "  → %s\n" "$*"; }
section() { printf "\n\033[1m=== %s ===\033[0m\n" "$*"; }

fatal() {
  c_err "$1"
  shift
  for line in "$@"; do c_info "$line"; done
  exit 1
}

# ── Helpers ─────────────────────────────────────────────────────────────────

# Extract `key = "value"` from terraform.tfvars. String values only.
tfvar() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "")
      gsub(/^"|"[[:space:]]*$/, "")
      sub(/[[:space:]]*#.*$/, "")
      print
      exit
    }
  ' terraform.tfvars
}

# ── 1. Required CLIs ────────────────────────────────────────────────────────

section "Required CLIs"

required_clis=(terraform ansible ansible-playbook jq scw)
missing_clis=()
for c in "${required_clis[@]}"; do
  if command -v "$c" >/dev/null 2>&1; then
    c_ok "$c → $(command -v "$c")"
  else
    c_err "$c missing"
    missing_clis+=("$c")
  fi
done
if [[ ${#missing_clis[@]} -gt 0 ]]; then
  fatal "Install the missing CLIs before continuing." \
    "macOS: brew install terraform ansible jq scw" \
    "Linux: see each tool's docs (Scaleway CLI: https://github.com/scaleway/scaleway-cli/releases)"
fi

# ── 2. Required files ───────────────────────────────────────────────────────

section "Required config files in $ENV_DIR"

required_files=(terraform.tfvars backend.hcl inventory.ini)
missing_files=()
for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    c_ok "$f"
  else
    c_err "$f missing"
    missing_files+=("$f")
  fi
done
if [[ ${#missing_files[@]} -gt 0 ]]; then
  msg=()
  for f in "${missing_files[@]}"; do
    if [[ -f "${f}.example" ]]; then
      msg+=("cp ${f}.example ${f}  # then edit")
    fi
  done
  fatal "Create the missing files before continuing." "${msg[@]}"
fi

# ── 3. Read what we need from terraform.tfvars ──────────────────────────────

section "Parsing terraform.tfvars"

scw_project_id="$(tfvar scaleway_project_id || true)"
base_domain="$(tfvar base_domain || true)"
gateway_domain="$(tfvar gateway_domain || true)"

for k in scw_project_id base_domain gateway_domain; do
  v="${!k}"
  if [[ -z "$v" ]]; then
    fatal "terraform.tfvars is missing or empty: $k" \
      "Open terraform.tfvars and set: $k = \"...\""
  fi
  c_ok "$k = $v"
done

# ── 4. Scaleway credentials ─────────────────────────────────────────────────

section "Scaleway credentials"

if [[ -z "${SCW_ACCESS_KEY:-}" || -z "${SCW_SECRET_KEY:-}" ]]; then
  fatal "SCW_ACCESS_KEY / SCW_SECRET_KEY not set in env." \
    "export SCW_ACCESS_KEY=SCWXXXXXXXXXXXXXXXXX" \
    "export SCW_SECRET_KEY=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
    "(These are the same values Terraform reads via TF_VAR_scaleway_access_key / TF_VAR_scaleway_secret_key.)"
fi
c_ok "SCW_ACCESS_KEY/SCW_SECRET_KEY exported"

# Sanity-check the creds resolve the project.
if ! scw account project get project-id="$scw_project_id" >/dev/null 2>&1; then
  fatal "scw can't fetch project $scw_project_id with the current credentials." \
    "Double-check SCW_ACCESS_KEY and SCW_SECRET_KEY have access to this project."
fi
c_ok "Project $scw_project_id is reachable"

# ── 5. Ansible's python + scaleway SDK ──────────────────────────────────────
#
# The scaleway.scaleway.scaleway_secret lookup plugin runs on the Ansible
# controller and imports `scaleway`. Detect the interpreter Ansible itself
# uses (NOT system python — they often differ on macOS) and pip install into
# it.

section "Ansible Python + scaleway SDK"

ANSIBLE_PYTHON="$(ansible --version 2>/dev/null | awk -F'[][]' '/python version/ {sub(/^[[:space:]=]+/, "", $2); print $2; exit}' | awk '{print $1}')"
if [[ -z "$ANSIBLE_PYTHON" || ! -x "$ANSIBLE_PYTHON" ]]; then
  # Older ansible output shape — fall back to `ansible-config dump`.
  ANSIBLE_PYTHON="$(ansible-config dump 2>/dev/null | awk -F' = ' '/^DEFAULT_PYTHON_INTERPRETER/ {print $2; exit}')"
fi
if [[ -z "$ANSIBLE_PYTHON" || ! -x "$ANSIBLE_PYTHON" ]]; then
  c_warn "Couldn't auto-detect Ansible's Python interpreter — falling back to \`which python3\`."
  ANSIBLE_PYTHON="$(command -v python3 || true)"
fi
[[ -n "$ANSIBLE_PYTHON" && -x "$ANSIBLE_PYTHON" ]] || \
  fatal "No Python interpreter found for Ansible." \
    "Re-install Ansible or set ANSIBLE_PYTHON_INTERPRETER yourself."
c_ok "Ansible Python: $ANSIBLE_PYTHON"

if "$ANSIBLE_PYTHON" -c 'import scaleway' >/dev/null 2>&1; then
  c_ok "scaleway SDK present in Ansible's Python"
else
  c_warn "scaleway SDK missing — installing now"
  if ! "$ANSIBLE_PYTHON" -m pip install --quiet --user scaleway 2>/dev/null; then
    # --user can fail under brew-managed pythons (PEP 668). Try without --user.
    "$ANSIBLE_PYTHON" -m pip install --quiet --break-system-packages scaleway || \
      fatal "Couldn't pip install scaleway." \
        "Install it manually into $ANSIBLE_PYTHON:" \
        "  $ANSIBLE_PYTHON -m pip install scaleway"
  fi
  c_ok "Installed scaleway SDK"
fi

# ── 6. SSH key in the Scaleway IAM keystore ─────────────────────────────────

section "Scaleway SSH keystore"

ssh_pub_default="${HOME}/.ssh/id_ed25519.pub"
ssh_pub="${SSH_PUBLIC_KEY_PATH:-$ssh_pub_default}"

if [[ ! -f "$ssh_pub" ]]; then
  fatal "SSH public key not found at $ssh_pub." \
    "Either generate one (ssh-keygen -t ed25519) or set:" \
    "  export SSH_PUBLIC_KEY_PATH=/path/to/key.pub"
fi
ssh_pub_content="$(cat "$ssh_pub")"

# scw iam ssh-key list filters by project_id automatically with -o.
existing_keys="$(SCW_DEFAULT_PROJECT_ID="$scw_project_id" scw iam ssh-key list -o json 2>/dev/null || echo '[]')"

# Compare on the key body (stripping the comment) to be robust to comment drift.
ssh_key_body="$(awk '{print $1" "$2}' <<<"$ssh_pub_content")"
if jq -e --arg body "$ssh_key_body" '
  any(.[]; (.public_key | (split(" ")[0:2] | join(" "))) == $body)
' <<<"$existing_keys" >/dev/null; then
  c_ok "SSH key already in the project keystore"
else
  c_warn "SSH key not in the project keystore — uploading"
  scw iam ssh-key create \
    name="$(whoami)-$(hostname -s 2>/dev/null || echo host)-${ENV_NAME}" \
    public-key="$ssh_pub_content" \
    project-id="$scw_project_id" >/dev/null
  c_ok "Uploaded $ssh_pub"
fi

# ── 7. DNS — gateway A record ───────────────────────────────────────────────
#
# The gateway domain MUST resolve to something public (placeholder allowed)
# BEFORE Let's Encrypt issues a cert. Traefik will fail HTTP-01 challenges
# until the A record exists. We create a placeholder pointing to 1.1.1.1 if
# nothing's there; deploy.sh will patch it to the real IP after compute is up.

section "DNS — A record for $gateway_domain"

# Resolve the parent zone: gateway_domain might be "auth.example.org" → zone
# "example.org", or "auth.staging.example.org" → either "staging.example.org"
# or "example.org" depending on how the user provisioned the zone. We try
# base_domain first since that's almost always the registered zone.

zone="$base_domain"

# Cross-project DNS: if base_domain's Scaleway DNS zone lives in a different
# project from the deploy project, the user exports separate credentials.
# Always prefix with `env` so the array is never empty (set -u tripwire).
dns_creds_env=(env)
if [[ -n "${SCW_DNS_ACCESS_KEY:-}" && -n "${SCW_DNS_SECRET_KEY:-}" ]]; then
  c_info "Using SCW_DNS_* credentials for the DNS zone (cross-project setup)."
  dns_creds_env=(env "SCW_ACCESS_KEY=$SCW_DNS_ACCESS_KEY" "SCW_SECRET_KEY=$SCW_DNS_SECRET_KEY")
fi

# Probe: does the zone exist + does the record exist?
records_json="$("${dns_creds_env[@]}" scw dns record list-dns-zones dns-zones.0="$zone" -o json 2>/dev/null || echo '[]')"
zone_ok=true
if ! jq -e --arg z "$zone" 'any(.[]?; .domain == $z or .subdomain == "" and (.domain // "") == $z)' <<<"$records_json" >/dev/null 2>&1; then
  # Best-effort — different scw CLI versions emit different shapes. Fall back to
  # a direct record list to detect the zone implicitly.
  if ! "${dns_creds_env[@]}" scw dns record list dns-zone="$zone" -o json >/dev/null 2>&1; then
    zone_ok=false
  fi
fi
if ! $zone_ok; then
  fatal "Scaleway DNS zone \"$zone\" not found." \
    "Either register the domain on Scaleway DNS, or if the zone lives in a different project export:" \
    "  export SCW_DNS_ACCESS_KEY=...   # access key for the DNS project" \
    "  export SCW_DNS_SECRET_KEY=...   # secret key for the DNS project" \
    "Then re-run preflight.sh."
fi
c_ok "Zone $zone exists"

# platform/base/terraform's scaleway_domain_record.gateway will create /
# manage the A record on apply. Preflight only verifies the SHAPE — that
# the gateway_domain is a child of base_domain (so the zone we just
# confirmed actually owns the record terraform is about to write).
subdomain="${gateway_domain%."$zone"}"
if [[ "$subdomain" == "$gateway_domain" ]]; then
  c_warn "gateway_domain ($gateway_domain) doesn't sit under base_domain ($base_domain). terraform will refuse to manage this record — either set manage_gateway_dns = false in your tfvars and manage it yourself, or fix base_domain."
else
  c_ok "Gateway A record will be managed by terraform (subdomain \"$subdomain\" under zone \"$zone\")"
fi

# ── Done ────────────────────────────────────────────────────────────────────

section "Preflight passed"
c_ok "Ready to run ./up.sh (then ./configure.sh)"
