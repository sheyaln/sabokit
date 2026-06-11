# sabokit-runner image

The runner image is `ghcr.io/sheyaln/sabokit-runner:<tag>`. It bundles ansible-core + four collections + the Terraform CLI + the Scaleway CLI + the entire `platform/` tree + `consumer-template/` at the matching repo tag — everything the four-layer scripts need. Published on every `v*` tag push by `.github/workflows/runner-publish.yml`, multi-arch for `linux/amd64` + `linux/arm64`.

**Consumers use [sabokit-cli](https://github.com/sheyaln/sabokit-cli) as the wrapper** — `sabokit up` / `deploy` / `destroy` / `refresh` run the layer scripts in this image with the right flags, mounts, and SSH-agent passthrough.

This document covers the runner image directly for sabokit-cli developers and for anyone debugging by skipping the CLI layer.

## Execution model

The consumer repo is mounted read-write at `/workspace/consumer` and the layer scripts run with that as cwd. `/workspace/sabokit` is a baked symlink to `/opt/sabokit`, so the consumer's `ansible-local/site.yml` resolves its `../../sabokit/platform/ansible/site.yml` sibling-checkout import unchanged. Script resolution is consumer-first: a vendored `scripts/` in the consumer repo wins; otherwise the baked `/opt/sabokit/consumer-template/scripts/` (which matches the image tag, which matches the env's pin) runs.

Consumer-local roles live in `ansible-local/roles/` — `lib.sh` appends that to `ANSIBLE_ROLES_PATH` after upstream roles, and `ansible-local/site.yml` is the play wrapper that imports upstream's `site.yml` plus any local plays.

## Raw docker invocation

What sabokit-cli's `up`/`deploy` build. Use directly when bypassing the CLI for debugging — `sabokit up --print` / `sabokit deploy --print` print the exact invocation.

```
docker run --rm -it \
  -v "$PWD:/workspace/consumer" -w /workspace/consumer \
  -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
  -e SCW_ACCESS_KEY -e SCW_SECRET_KEY \
  --entrypoint bash \
  ghcr.io/sheyaln/sabokit-runner:vX.Y.Z \
  /opt/sabokit/consumer-template/scripts/up.sh <env>
```

Swap `up.sh <env>` for `identity.sh <env>`, `deploy.sh <env> <tags>`, `refresh.sh <env>`, `destroy-layer.sh <env> <layer>`, or `down.sh <env>` as needed.

## What's in the image

Built on `python:3.12-slim`.

| component | pin | source |
| --- | --- | --- |
| ansible-core | `ANSIBLE_CORE_VERSION` build arg (default 2.18.1) | pip |
| terraform CLI | `TERRAFORM_VERSION` build arg (default 1.10.5) | hashicorp release zip |
| scaleway CLI | `SCW_CLI_VERSION` build arg (default 2.56.0) | github release binary |
| ansible collections | locked by ansible-core resolution at build | `community.docker`, `community.general`, `ansible.posix`, `scaleway.scaleway` |
| python deps | unpinned (rebuilt per tag) | `requests`, `jmespath`, `passlib`, `docker`, `scaleway` |
| OS pkgs | apt baseline | `openssh-client`, `git`, `ca-certificates`, `curl`, `jq`, `sshpass`, `unzip` |
| platform/ + consumer-template/ trees | match the image tag | baked from the repo at build time |

Not in the image: secrets, TF state. Both stay on the consumer side (state in the per-env bucket, secrets in Scaleway secret manager / the environment).

## Workdir + entrypoint

Entrypoint: `ansible-playbook`. Default WORKDIR: `/opt/sabokit/platform/ansible` (bare ansible invocations). Layer-script runs override both (`--entrypoint bash -w /workspace/consumer`), and the scripts invoke terraform/ansible/scw themselves with the right dirs.

sabokit-cli (the Go CLI installed via `curl -fsSL https://raw.githubusercontent.com/sheyaln/sabokit-cli/master/install.sh | bash`) wraps all of this.

## Scaleway state-backend credentials

Terraform reads Scaleway creds from env. Pass via `-e` or `--env-file`:

| env var | purpose |
| --- | --- |
| `SCW_ACCESS_KEY` | API key for state R/W + resource ops |
| `SCW_SECRET_KEY` | matching secret |
| `SCW_DEFAULT_ORGANIZATION_ID` | org for default provider |
| `SCW_DEFAULT_PROJECT_ID` | project for default provider |

Image is also what sabokit-cli shells out to.
