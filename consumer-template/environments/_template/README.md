# environments/_template

Copy this dir to create a new environment:

```bash
cp -r environments/_template environments/prod
cp -r environments/_template environments/staging
```

Then per env:

```bash
cd environments/prod
cp config.tf.example  config.tf                  # the consumer's authoritative config — commit this
cp backend.hcl.example backend.hcl               # remote state config (gitignored)
cp inventory.ini.example inventory.ini           # placeholder; up.sh rebuilds from terraform output
chmod +x preflight.sh up.sh configure.sh
```

`config.tf` is committable. It carries the entire infra spec for this env as
a `locals { config = {...} }` block. The only things that stay out of git
are runtime credentials (`SCW_ACCESS_KEY` / `SCW_SECRET_KEY` via env) and
the Authentik admin token (auto-fetched by `configure.sh` after `up.sh`).

Need a value from Scaleway Secret Manager wired through Terraform? Add a
`data "scaleway_secret_version"` block in `secrets.tf` — bag UUIDs are
committable, payloads stay in Scaleway.

## Deploy in three steps

Each step has a verifiable checkpoint — stop, look, then continue. Re-running any step is safe.

```bash
./preflight.sh          # one-time per env: CLI deps, SSH key, DNS placeholder
./up.sh                 # provision infra + install Authentik
./configure.sh          # configure Authentik (flows, brand, groups) + app TF
```

Checkpoints:

| After | Verify with |
|---|---|
| `up.sh`        | `curl -sf https://<gateway_domain>/api/v3/root/config/` returns 200. Authentik is reachable but unconfigured. |
| `configure.sh` | Log in to the gateway as `akadmin`. Flows, brand, groups, any enabled app's OIDC provider are visible. |

## Deploy / update apps

Apps are deployed by the `apps.yml` Ansible playbook. No wrapper script — the
command is short enough to copy:

```bash
ansible-playbook \
  "$FED_COMMONS_DIR/platform/ansible/apps.yml" \
  -i inventory.ini \
  -e @.ansible-vars.json \
  -e env_name="$(basename "$PWD")" \
  -e gateway_domain="$(awk -F= '/^[[:space:]]*gateway_domain/{gsub(/[ "#]/, "", $2); print $2; exit}' config.tf)"
```

Common variants:

```bash
# Deploy a single app + dependencies
...apps.yml ... --tags outline

# Skip the full Ansible run, just re-render configs
...apps.yml ... --skip-tags compose
```

`FED_COMMONS_DIR` defaults to `../../../sabokit` (sibling of the
consumer repo). Override with `FED_COMMONS_DIR=/path/to/sabokit`
if your layout differs.

## Smoke test

```bash
# Each enabled app's URL should redirect to Authentik (302/303) or
# render its own UI (200).
jq -r '.enabled_apps.value | to_entries[] | select(.value != null) | .value.url' .tf-output.json | while read -r url; do
  printf "%-50s %s\n" "$url" "$(curl -sfo /dev/null -w '%{http_code}' --max-time 15 "$url" || echo CONNECT_FAIL)"
done
```

## Re-deploys

Day-to-day work usually only needs `apps.yml`. Re-run `configure.sh` when you
add/remove an app in `config.tf` or change platform/identity config. Re-run
`up.sh` only when the VPC/host topology or Authentik install changes —
usually after a sabokit version bump.

`./up.sh` accepts trailing args that get forwarded to `ansible-playbook
bootstrap.yml` — for example `./up.sh --skip-tags bootstrap` to short-circuit
the heavy roles if you know the host is already bootstrapped.
