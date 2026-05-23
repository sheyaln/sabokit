#!/usr/bin/env bash
# Configure the running Authentik + provision app infrastructure. Step 2 of 3.
#
#   ./preflight.sh
#   ./up.sh
#   ./configure.sh    ← you are here
#
# What configure.sh does:
#   1. Read the Authentik admin API token from the Scaleway secret that
#      up.sh's identity_bootstrap pre-generated.
#   2. Import the auto-created "authentik Embedded Outpost" into terraform
#      state IF the platform expects to manage it (i.e. at least one
#      forward-auth app is enabled). Silent no-op otherwise.
#   3. terraform apply (full) — the identity module configures flows, brand,
#      groups, the embedded outpost. Every enabled app's terraform runs too
#      (OIDC providers, per-app databases, S3 buckets, ...).
#   4. Refresh .ansible-vars.json from the new terraform outputs.
#
# Exit checkpoint: log in to https://<gateway_domain> as akadmin
# (password in the Scaleway admin-bootstrap secret) and you should see all
# flows, brand, groups, and any enabled app's OIDC provider in the UI.
#
# Then deploy apps with:
#   ansible-playbook \
#     "$FED_COMMONS_DIR/platform/ansible/apps.yml" \
#     -i inventory.ini -e @.ansible-vars.json \
#     -e env_name="$(basename "$PWD")" \
#     -e gateway_domain="$(awk '/^[[:space:]]*gateway_domain/{...}' terraform.tfvars)"
# (full one-liner in README.md)
#
# Idempotent: re-run any time platform/identity config or app terraform changes.

# shellcheck disable=SC1091
. "$(dirname "$0")/_lib.sh"

require_files .tf-output.json

# ── 1. Read the admin API token from Scaleway Secret Manager ────────────────

c_phase "1/3  Read Authentik admin API token from Scaleway secret"

ADMIN_SECRET_ID="$(jq -r '.authentik_admin_secret_id.value' .tf-output.json)"
[[ -n "$ADMIN_SECRET_ID" && "$ADMIN_SECRET_ID" != "null" ]] || {
  c_err "authentik_admin_secret_id not in terraform output."
  c_info "Did ./up.sh complete? identity_bootstrap creates this secret in step 1."
  exit 1
}
# Scaleway TF outputs as "<region>/<uuid>" — the CLI wants the bare UUID.
ADMIN_SECRET_UUID="${ADMIN_SECRET_ID##*/}"
ADMIN_TOKEN="$(scw secret version access secret-id="$ADMIN_SECRET_UUID" revision=latest -o json \
                | jq -r '.data' | base64 -d | jq -r '.api_token')"
[[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "null" ]] || {
  c_err "Couldn't read api_token from the admin secret. Did up.sh phase 1 generate it?"
  exit 1
}
c_ok "Token fetched"

# ── 2. Import the embedded outpost if we expect to manage it ────────────────

c_phase "2/3  Reconcile Authentik embedded outpost"

# Authentik auto-creates the "authentik Embedded Outpost" on first boot.
# The platform's authentik_outpost.embedded resource is conditional
# (count = 1 only when forward-auth providers exist). When count = 1, the
# first apply must IMPORT the existing outpost so terraform doesn't try to
# POST a duplicate. Idempotent:
#   - count = 0 (no forward-auth apps): import attempt is a silent no-op.
#   - count = 1 and already in state: skipped.
#   - count = 1 and not in state: imported.
OUTPOST_ADDR='module.stack.module.identity.authentik_outpost.embedded[0]'
if ! terraform state show "$OUTPOST_ADDR" >/dev/null 2>&1; then
  OUTPOST_ID="$(curl -sk -H "Authorization: Bearer $ADMIN_TOKEN" \
    "https://${GATEWAY_DOMAIN}/api/v3/outposts/instances/?name=authentik%20Embedded%20Outpost" \
    | jq -r '.results[0].pk')"
  if [[ -n "$OUTPOST_ID" && "$OUTPOST_ID" != "null" ]]; then
    if terraform import -var "authentik_admin_token=$ADMIN_TOKEN" \
         "$OUTPOST_ADDR" "$OUTPOST_ID" >/dev/null 2>&1; then
      c_ok "Embedded outpost imported into terraform state"
    else
      c_ok "No forward-auth providers enabled — skipping outpost import"
    fi
  fi
else
  c_ok "Outpost already in state"
fi

# ── 3. Full terraform apply ─────────────────────────────────────────────────

c_phase "3/3  Terraform apply (identity config + app infra)"

# -var beats both TF_VAR_* and any value lingering in terraform.tfvars.
terraform apply -auto-approve -input=false \
  -var "authentik_admin_token=$ADMIN_TOKEN"
c_ok "Apply complete"

# Refresh .ansible-vars.json — outputs from this apply matter for apps.yml.
terraform output -json > .tf-output.json
jq '{
  enabled_apps:               .enabled_apps.value,
  compute_hosts:              .compute_hosts.value,
  authentik_gateway_domain:   .authentik_gateway_domain.value,
  identity_bootstrap:         .identity_bootstrap.value,
  traefik_acme_email:         .infra_email.value,
}' .tf-output.json > .ansible-vars.json

c_phase "configure.sh done"
c_info "Authentik is fully configured. Log in at https://$GATEWAY_DOMAIN as akadmin"
c_info "  (password: scw secret version access secret-id=$ADMIN_SECRET_UUID revision=latest | jq -r '.data' | base64 -d | jq -r '.password')"
c_info "Next: deploy apps. See README.md for the ansible-playbook command."
