# environments/_template

Copy this directory to create an environment. The directory **name is the
environment name** — `env.tf` uses it to select this env's slice from
`../env-values.yml` at plan time.

```bash
cp -r environments/_template environments/prod
cd environments/prod
cp config.tf.example   config.tf       # persistent infra shape — commit it
cp backend.hcl.example backend.hcl     # remote-state bucket — gitignored
```

Add this env's block to `environments/env-values.yml` (copy
`env-values.yml.example` first if it doesn't exist yet):

```yaml
prod:
  scaleway_project_id: "…"
  base_domain: "example.org"
  identity_domain: "auth.example.org"
  infra_email: "ops@example.org"
```

## What lives where

| File | In git? | Holds |
|---|---|---|
| `config.tf` | yes | persistent infra SHAPE (`locals.config`), identical across envs |
| `../env-values.yml` | yes | per-env NON-secret values, keyed by env name |
| `env.tf` | yes | resolves this dir's slice → `local.env` / `local.env_name` |
| `main.tf` `providers.tf` `variables.tf` `secrets.tf` | yes | wiring, identical across envs |
| `backend.hcl` | no | this env's remote-state bucket |
| `.envrc` | no | secrets: `SCW_ACCESS_KEY` / `SCW_SECRET_KEY`, `TF_VAR_authentik_admin_token` |

No env-specific value is stored in this directory — they live keyed in
`env-values.yml` — so copying an env dir can't carry another env's project_id
or domains into the wrong place.

Need a Scaleway Secret Manager value wired through Terraform? Add a
`data "scaleway_secret_version"` to `secrets.tf` (bag UUIDs are committable,
payloads stay in Scaleway).

## Deploy

Export credentials first (both paths need them):

```bash
export SCW_ACCESS_KEY=… SCW_SECRET_KEY=…
```

### sabokit CLI — assisted (recommended)

Orchestrates the two terraform phases, the ansible bootstrap, the Authentik
admin-token fetch, and every enabled app's playbook:

```bash
sabokit --env prod up
```

### Plain terraform + ansible — manual (no CLI)

`terraform apply` works here standalone: `env.tf` reads `env-values.yml`
itself. Authentik doesn't exist on the first deploy, so terraform runs in two
phases:

```bash
terraform -chdir=environments/prod init -backend-config=backend.hcl

# Phase 1 — Scaleway primitives + Authentik install (no token yet)
terraform -chdir=environments/prod apply \
  -target=module.stack.module.base \
  -target=module.stack.module.identity_bootstrap

# Host bootstrap. Needs inventory.ini + .ansible-vars.json derived from TF
# output — `sabokit deploy` generates both; by hand, build them from
# `terraform output -json`.
ansible-playbook "$SABOKIT_DIR/platform/ansible/site.yml" \
  -i inventory.ini -e @.ansible-vars.json --tags bootstrap

# Phase 2 — full apply, now with the Authentik admin token
export TF_VAR_authentik_admin_token="…"   # from the bootstrap admin scaleway secret
terraform -chdir=environments/prod apply
```

That orchestration is exactly what `sabokit up` automates. The point of the
manual path is that nothing is hidden — `terraform plan/apply` is always
runnable on its own.

## Deploy / update apps

Apps converge via the `site.yml` ansible playbook:

```bash
ansible-playbook "$SABOKIT_DIR/platform/ansible/site.yml" \
  -i inventory.ini -e @.ansible-vars.json \
  -e env_name="$(basename "$PWD")" \
  --tags outline          # one app; drop --tags for the full run
```

`SABOKIT_DIR` defaults to `../../../sabokit` (sibling of the consumer repo);
override if your layout differs. `sabokit deploy --apps outline` does the same
with the inventory + vars generated for you.

## Smoke test

```bash
# Each enabled app's URL should redirect to Authentik (302/303) or render its
# own UI (200). -L follows redirects to the final code.
jq -r '.enabled_apps.value | to_entries[] | select(.value != null) | .value.url' .tf-output.json | while read -r url; do
  printf "%-50s %s\n" "$url" "$(curl -sfo /dev/null -w '%{http_code}' --max-time 15 -L "$url" || echo CONNECT_FAIL)"
done
```
