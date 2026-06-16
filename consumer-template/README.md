# consumer-template

The starter you copy into your own infrastructure repo. An environment is
**four Terraform roots** — one per layer (infra, identity, operations,
application), each its own state — driven by committed YAML config and deployed
by the per-layer scripts.

## Layout

```
consumer-template/
├── environments/
│   ├── common.yml                # org_slug, org_name, icon_base_url (cross-env)
│   ├── _template/                # copy this to create an env (dir name = env name)
│   │   ├── env.yml               # per-env scope/domains/sizing
│   │   ├── hosts.yml             # compute-host topology
│   │   ├── infra.yml             # infra-layer knobs
│   │   ├── identity.yml          # the Authentik tier DAG + branding
│   │   ├── operations.yml        # observability + protonmail-bridge
│   │   ├── application.yml        # the app suite
│   │   ├── infra/        { stack.tf, providers.tf, outputs.tf, backend.hcl.example }
│   │   ├── identity/     { … }
│   │   ├── operations/   { … }
│   │   ├── application/  { … }
│   │   ├── .gitignore
│   │   └── README.md             # the per-env runbook
│   └── (your envs land here)
├── apps-manifest.yaml            # GUI-consumable declaration of every app bundle
├── ansible-local/                # your org-only roles (wrap platform's site.yml)
├── scripts/
│   ├── lib.sh                    # shared deploy engine (sourced)
│   ├── infra.sh / identity.sh / operations.sh / application.sh
│   ├── up.sh / down.sh           # all layers, in dependency order
│   ├── bump-version.sh           # sync common.yml sabokit_version -> every ?ref= pin
│   └── import-base-image.sh
└── README.md
```

Each layer's `stack.tf` reads the YAML and calls the pinned platform layer
(`//platform/<layer>/terraform?ref=vX.Y.Z`). The layers self-discover each
other by name (`${org}-${env}-…` tags) — there is no remote_state between them.

## Quick start

The supported path is [sabokit-cli](https://github.com/sheyaln/sabokit-cli),
which wraps every terraform / ansible / scaleway-cli call in pinned docker
images (host needs only `docker` + `ssh`):

```bash
curl -fsSL https://raw.githubusercontent.com/sheyaln/sabokit-cli/master/install.sh | bash
export SCW_ACCESS_KEY=... SCW_SECRET_KEY=... SCW_DEFAULT_PROJECT_ID=...

sabokit init my-stack && cd my-stack
$EDITOR environments/prod/env.yml          # project_id / domains / sizing
$EDITOR environments/prod/application.yml   # which apps, at which hostnames
sabokit up                                  # infra → identity → operations → application
```

**The CLI is an assistant, not a requirement** — it shells out to the same
`scripts/*.sh`. The manual path needs `terraform`, `ansible`, `jq`, `python3`,
and `scw` on PATH:

```bash
cp -r environments/_template environments/prod
$EDITOR environments/prod/env.yml
for l in infra identity operations application; do
  cp environments/prod/$l/backend.hcl.example environments/prod/$l/backend.hcl   # set the bucket
done
export SCW_ACCESS_KEY=... SCW_SECRET_KEY=...
scripts/up.sh prod            # or one layer at a time: scripts/infra.sh prod, …
scripts/down.sh prod          # teardown, reverse order
```

Each env has its own state, credentials, and deploy. See
`environments/_template/README.md` for the per-env runbook and the apply rhythm.

## Adding an app

Add (or uncomment) a block in `environments/<env>/application.yml` with the
app's `enabled`, full `hostname`, and any overrides (see `apps-manifest.yaml`
for each bundle's inputs), then redeploy the application layer:

```bash
scripts/application.sh prod        # terraform apply + ansible, app layer only
```

`authorized_groups` defaults per app (member-collaboration / delegate-management
/ admin-infra); override it to widen or narrow access. Listing a baseline tier
admits that tier and every higher one via Authentik group nesting.

## Bumping sabokit

The pinned version's source of truth is `environments/common.yml`
(`sabokit_version`). Terraform can't read a module `source` from YAML, so
`bump-version.sh` propagates that value into every `stack.tf` `?ref=`.

```bash
./scripts/bump-version.sh v1.1.0   # set common.yml + sync every ?ref= + the sabokit checkout
./scripts/bump-version.sh          # re-sync stack.tf to whatever common.yml says
# then re-init + plan each layer of each env (the script prints the loop)
```

Major bumps may require `terraform state mv` — check the release notes.

## Secrets hygiene

The config YAML is committed (non-secret, reviewable). `backend.hcl`,
`inventory.ini`, fetched `.json` runtime artifacts, and `.env`/`.envrc` are
gitignored; `.example` siblings are tracked. Credentials come from `SCW_*` env
vars (or a gitignored `.envrc`); the Authentik admin token is fetched from the
infra bootstrap secret by the deploy scripts — never a committed file.

## Required tools (manual path)

```bash
brew install terraform ansible jq python3 scaleway-cli   # or apt/dnf equivalents
ansible-galaxy collection install community.docker community.general scaleway.scaleway
```
