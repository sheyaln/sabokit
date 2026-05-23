#!/usr/bin/env bash
# Bring the platform UP. Step 1 of 3.
#
#   ./preflight.sh
#   ./up.sh         ← you are here
#   ./configure.sh
#
# What up.sh does:
#   1. terraform apply (base + identity_bootstrap)  — VPC, hosts, postgres,
#      bootstrap secrets (incl. the pre-generated admin api_token).
#   2. Inventory regen + DNS update + SSH wait      — patches inventory.ini
#      with current public IPs, promotes the placeholder gateway A record to
#      the real identity host IP, clears stale known_hosts entries, waits
#      for sshd on every host.
#   3. ansible-playbook bootstrap.yml               — docker, traefik,
#      scw-secrets, monitoring-agent on every host, plus authentik-server on
#      the [identity] host. Authentik picks up AUTHENTIK_BOOTSTRAP_TOKEN and
#      creates the matching API Token on first boot.
#   4. Wait for Let's Encrypt to mint the gateway cert. Forces a Traefik
#      restart at 60s if the cert hasn't materialized yet.
#
# Exit checkpoint: `curl https://<gateway_domain>/api/v3/root/config/` returns
# 200. Authentik is up but empty (no flows, no brand, no apps — that's step 2).
#
# Idempotent: every step is safe to re-run.

# shellcheck disable=SC1091
. "$(dirname "$0")/_lib.sh"

# ── 1. terraform apply (base + identity_bootstrap) ──────────────────────────

c_phase "1/4  Terraform apply (base + identity bootstrap)"
terraform apply \
  -target=module.stack.module.base \
  -target=module.stack.module.identity_bootstrap \
  -auto-approve \
  -input=false
c_ok "Base + identity_bootstrap applied"

terraform output -json > .tf-output.json

# ── 2. Inventory + DNS + SSH reachability ───────────────────────────────────

c_phase "2/4  Inventory + DNS + SSH"

# Rebuild inventory.ini from compute_hosts output. Each host becomes a host
# named "<host_key>-<env>" with the current public IP, grouped under its
# ansible_group. Re-running cleanly handles IP changes after re-provision.
python3 - <<'PYEOF' .tf-output.json "$ENV_NAME" > inventory.ini
import json, sys, collections
data = json.load(open(sys.argv[1]))
env = sys.argv[2]
hosts = data["compute_hosts"]["value"]
# Each host registers under its primary ansible_group AND every group in
# ansible_groups. Single-VM staging typically sets ansible_groups =
# ["apps", "identity"] so the bootstrap.yml plays that select on those
# group names actually have a host to target.
by_group = collections.defaultdict(list)
for short, h in hosts.items():
    line = (
        # Scaleway's ubuntu_jammy image uses the root account as the
        # cloud-init user. Override here if you use a different image.
        f'{short}-{env} ansible_host={h["public_ip"]} ansible_user=root'
    )
    groups = [h["ansible_group"], *(h.get("ansible_groups") or [])]
    for g in dict.fromkeys(groups):  # dedupe, preserve order
        by_group[g].append(line)
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

# Gateway DNS is now managed by platform/base/terraform via the
# scaleway_domain_record resource — the A record is created in the same
# step 1 apply that provisions the identity host, so by the time we hit
# step 4's LE check the record already points at the right IP. No shell
# DNS update needed here.

# Clear stale known_hosts entries (host key drift across re-provisions).
IPS=($(jq -r '.compute_hosts.value | to_entries[] | .value.public_ip' .tf-output.json))
for ip in "${IPS[@]}"; do
  ssh-keygen -R "$ip" >/dev/null 2>&1 || true
done

# Wait for SSH on every host (up to 5min each). Port-22 reachability only —
# we don't authenticate here because the inventory may use root vs. ubuntu
# depending on the image.
for ip in "${IPS[@]}"; do
  c_info "Waiting for SSH on $ip ..."
  for attempt in $(seq 1 60); do
    if nc -zw 5 "$ip" 22 2>/dev/null; then
      sleep 3  # let sshd settle
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

# ── 3. ansible bootstrap ────────────────────────────────────────────────────

# Build ansible-vars.json fresh; bootstrap.yml (and configure.sh / the apps
# playbook later) both read it.
jq '{
  enabled_apps:               .enabled_apps.value,
  compute_hosts:              .compute_hosts.value,
  authentik_gateway_domain:   .authentik_gateway_domain.value,
  identity_bootstrap:         .identity_bootstrap.value,
  traefik_acme_email:         .infra_email.value,
}' .tf-output.json > .ansible-vars.json

c_phase "3/4  Ansible bootstrap (docker, traefik, authentik-server)"
ANSIBLE_CONFIG="$FED_COMMONS_DIR/platform/ansible/ansible.cfg" \
ansible-playbook "$FED_COMMONS_DIR/platform/ansible/bootstrap.yml" \
  -i inventory.ini \
  -e @.ansible-vars.json \
  -e "env_name=$ENV_NAME" \
  -e "gateway_domain=$GATEWAY_DOMAIN" \
  -e "scaleway_project_id=$SCW_PROJECT_ID" \
  -e "traefik_acme_email=$INFRA_EMAIL" \
  "$@"
c_ok "Bootstrap complete"

# ── 4. Wait for Let's Encrypt cert ──────────────────────────────────────────

c_phase "4/4  Waiting for Let's Encrypt cert on $GATEWAY_DOMAIN"
IDENTITY_HOST="$(awk '/^\[identity\]/{flag=1; next} /^\[/{flag=0} flag && NF {for (i=1;i<=NF;i++) if ($i ~ /^ansible_host=/) {sub("ansible_host=","",$i); print $i; exit}}' inventory.ini)"
INV_USER="$(awk -v host="$IDENTITY_HOST" '$0 ~ ("ansible_host="host) {for (i=1;i<=NF;i++) if ($i ~ /^ansible_user=/) {sub("ansible_user=","",$i); print $i; exit}}' inventory.ini)"
cert_ok=false
for attempt in $(seq 1 24); do
  if curl -sfo /dev/null --max-time 10 "https://${GATEWAY_DOMAIN}/api/v3/root/config/"; then
    cert_ok=true
    break
  fi
  if [[ $attempt -eq 6 && -n "$IDENTITY_HOST" ]]; then
    c_warn "LE cert not yet valid after 60s — forcing Traefik restart"
    ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "${INV_USER:-ubuntu}@${IDENTITY_HOST}" \
      'sudo docker compose -f /opt/traefik/docker-compose.yml restart traefik' || true
  fi
  sleep 10
done
if $cert_ok; then
  c_ok "TLS reachable at https://${GATEWAY_DOMAIN}"
else
  c_err "Gateway not reachable after 4 minutes. Check Traefik logs:"
  c_info "  ssh ${INV_USER:-ubuntu}@${IDENTITY_HOST:-<identity-host>} 'sudo docker logs traefik --tail=100'"
  exit 1
fi

# Authentik's /api/v3/root/config/ returns 200 well before its built-in
# blueprints finish indexing (default flows, default brand, the RBAC
# permission table). configure.sh's terraform apply queries those resources
# as data sources and resource references — if it runs during the indexing
# window, it fails with "No matching flows found" / "permission not found".
# Probe a known-blueprint flow slug AND the RBAC permission table; both
# must return results before we declare up.sh done.
c_info "Waiting for Authentik blueprints + permission table to finish indexing..."
ADMIN_SECRET_ID="$(jq -r '.authentik_admin_secret_id.value' .tf-output.json)"
ADMIN_TOKEN="$(scw secret version access secret-id="${ADMIN_SECRET_ID##*/}" revision=latest -o json \
                | jq -r '.data' | base64 -d | jq -r '.api_token')"
# Every default-* flow slug that platform/identity/terraform/flows/data.tf
# references via `data "authentik_flow"`. All of them must be indexed before
# configure.sh's apply runs, otherwise the data source resolution fails with
# "No matching flows found". Authentik loads blueprints in parallel and
# different slugs surface at different times — polling just one isn't enough.
REQUIRED_FLOWS=(
  default-source-authentication
  default-source-enrollment
  default-invalidation-flow
  default-user-settings-flow
  default-provider-authorization-implicit-consent
  default-provider-invalidation-flow
)
blueprints_ok=false
for attempt in $(seq 1 30); do
  all_present=true
  for slug in "${REQUIRED_FLOWS[@]}"; do
    count="$(curl -sk -H "Authorization: Bearer $ADMIN_TOKEN" \
      "https://${GATEWAY_DOMAIN}/api/v3/flows/instances/?slug=$slug" \
      | jq -r '.pagination.count // 0')"
    [[ "$count" -ge 1 ]] || { all_present=false; break; }
  done
  perms="$(curl -sk -H "Authorization: Bearer $ADMIN_TOKEN" \
    "https://${GATEWAY_DOMAIN}/api/v3/rbac/permissions/?codename=view_application" \
    | jq -r '.pagination.count // 0')"
  if $all_present && [[ "$perms" -ge 1 ]]; then
    blueprints_ok=true
    break
  fi
  sleep 5
done
$blueprints_ok && c_ok "Blueprints + RBAC indexed" || {
  c_warn "Blueprints/permissions not yet indexed after 150s — configure.sh may need a retry"
}

c_phase "up.sh done"
c_info "Authentik is reachable at https://$GATEWAY_DOMAIN (but unconfigured)."
c_info "Next: ./configure.sh"
