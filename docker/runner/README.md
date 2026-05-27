# sabokit-runner image

The runner image is `ghcr.io/sheyaln/sabokit-runner:<tag>`. It bundles ansible-core + four collections + the Terraform CLI + the entire `platform/` tree at the matching repo tag. Published on every `v*` tag push by `.github/workflows/runner-publish.yml`.

**Consumers use [sabokit-cli](https://github.com/sheyaln/sabokit-cli) as the wrapper** — `sabokit deploy` / `sabokit down` / `sabokit status` run this image with the right flags, mounts, and SSH-agent passthrough. The standalone shell wrapper (`scripts/sabokit-runner.sh`) was removed at v3.4.0; sabokit-cli replaces it.

This document covers the runner image directly for sabokit-cli developers and for anyone debugging by skipping the CLI layer.

## Consumer overlays

`sabokit deploy --overlay DIR` mounts a consumer-side directory at `/consumer:ro` inside the runner. Two conventions:

- `DIR/extensions.yml` (if present) runs after upstream's `site.yml` in the same ansible process — shared facts cache, shared SSH connections. Use for gap apps that don't yet have an upstream bundle.
- `DIR/roles/` is appended to `ANSIBLE_ROLES_PATH` after upstream roles. Upstream wins on name collision. Consumers wanting to override an upstream role should fork the bundle.

`DIR/group_vars/` and `DIR/host_vars/` are picked up by ansible's normal precedence rules.

## Raw docker invocation

What sabokit-cli's `deploy` builds. Use directly when bypassing the CLI for debugging.

```
docker run --rm -it \
  -v "$PWD/env:/env:ro" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
  ghcr.io/sheyaln/sabokit-runner:vX.Y.Z \
  /opt/sabokit/platform/ansible/site.yml \
  -i /env/inventory.ini -e @/env/enabled_apps.json \
  [--tags <app>[,<app>...] | --skip-tags bootstrap | --limit <host>]
```

With an overlay:

```
docker run --rm -it \
  -v "$PWD/env:/env:ro" \
  -v "$PWD/ansible-local:/consumer:ro" \
  -e ANSIBLE_ROLES_PATH=/opt/sabokit/platform/apps:/opt/sabokit/platform/base/ansible/roles:/consumer/roles \
  -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
  ghcr.io/sheyaln/sabokit-runner:vX.Y.Z \
  /opt/sabokit/platform/ansible/site.yml /consumer/extensions.yml \
  -i /env/inventory.ini -e @/env/enabled_apps.json
```

`sabokit deploy --print [flags...]` prints the exact docker invocation sabokit-cli would run — useful for porting to CI/CD or one-off debugging.

## What's in the image

Built on `python:3.12-slim`.

| component | pin | source |
| --- | --- | --- |
| ansible-core | `ANSIBLE_CORE_VERSION` build arg (default 2.18.1) | pip |
| terraform CLI | `TERRAFORM_VERSION` build arg (default 1.10.5) | hashicorp release zip |
| ansible collections | locked by ansible-core resolution at build | `community.docker`, `community.general`, `ansible.posix`, `scaleway.scaleway` |
| python deps | unpinned (rebuilt per tag) | `requests`, `jmespath`, `passlib`, `docker` |
| OS pkgs | apt baseline | `openssh-client`, `git`, `ca-certificates`, `curl`, `jq`, `sshpass`, `unzip` |
| platform/ tree | matches the image tag | baked from the repo at build time |

Not in the image: consumer-template, secrets, TF state. State stays on the consumer side.

## Workdir + entrypoint

Entrypoint: `ansible-playbook`. Default WORKDIR: `/opt/sabokit/platform/ansible` (ansible-only invocations).

For terraform invocations, override the entrypoint and set workdir to the consumer's TF tree. Convention: mount it at `/project`:

```
docker run --rm -it \
  --entrypoint terraform \
  -v "$PWD/terraform:/project" -w /project \
  -e SCW_ACCESS_KEY -e SCW_SECRET_KEY \
  -e SCW_DEFAULT_ORGANIZATION_ID -e SCW_DEFAULT_PROJECT_ID \
  ghcr.io/sheyaln/sabokit-runner:vX.Y.Z \
  apply
```

sabokit-cli (the Go CLI installed via `curl -fsSL https://raw.githubusercontent.com/sheyaln/sabokit-cli/master/install.sh | bash`) wraps this and sets the workdir itself.

## Scaleway state-backend credentials

Terraform reads Scaleway creds from env. Pass via `-e` or `--env-file`:

| env var | purpose |
| --- | --- |
| `SCW_ACCESS_KEY` | API key for state R/W + resource ops |
| `SCW_SECRET_KEY` | matching secret |
| `SCW_DEFAULT_ORGANIZATION_ID` | org for default provider |
| `SCW_DEFAULT_PROJECT_ID` | project for default provider |

Image is also what sabokit-cli shells out to.
