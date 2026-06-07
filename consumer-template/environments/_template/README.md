# environments/_template

The copy-me template for one environment. An environment is **four Terraform
roots** (one per layer), each its own state, driven by committed YAML config.

```
_template/
  common.yml … (one level up, shared across envs)   org_slug, org_name, icon_base_url
  env.yml             per-env scope/domains/sizing + the env identity
  hosts.yml           compute-host topology (sizing merged from env.yml)
  infra.yml           infra-layer knobs
  identity.yml        the Authentik tier DAG + branding
  operations.yml      observability + protonmail-bridge
  application.yml     the app suite
  infra/        { stack.tf, providers.tf, outputs.tf, backend.hcl.example }
  identity/     { … }
  operations/   { … }
  application/  { … }
```

`stack.tf` reads the YAML and calls the pinned platform layer
(`//platform/<layer>/terraform?ref=vX.Y.Z`). The version pin lives in each
`stack.tf`; bump it with `scripts/bump-version.sh`.

## Create an environment

```bash
cp -r environments/_template environments/prod
# edit environments/prod/env.yml (project_id, domains, infra_email, sizing)
# edit environments/prod/*.yml as needed
for l in infra identity operations application; do
  cp environments/prod/$l/backend.hcl.example environments/prod/$l/backend.hcl
  # edit the bucket; the state key is already layer-specific
done
```

The directory NAME is the environment label, so a copied dir never carries
another env's project_id. Each env MUST use a distinct `scaleway_project_id`.

## Deploy

```bash
export SCW_ACCESS_KEY=… SCW_SECRET_KEY=…
scripts/up.sh prod            # infra → identity → operations → application
# or one layer at a time:
scripts/infra.sh prod
scripts/identity.sh prod
scripts/operations.sh prod
scripts/application.sh prod
scripts/down.sh prod          # reverse order
```

## Apply rhythm (why the layer order matters)

| Layer | Order | What it does |
|-------|-------|--------------|
| infra | TF | Scaleway substrate: VPC, hosts, Postgres (incl. Authentik's DB), TEM, secrets |
| identity | **ansible → TF** | boots the Authentik server, then configures it via the API |
| operations | TF → ansible | mints DBs + OIDC apps, then deploys observability |
| application | TF → ansible | mints per-app DBs + OIDC + the outpost, then deploys the apps |

Layers self-discover each other by name (the `${org}-${env}-…` tags) — there is
no remote_state between them. Apply infra first; the rest can re-run freely.
