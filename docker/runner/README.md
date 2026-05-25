# sabokit-runner image + sabokit-runner wrapper

The runner image is `ghcr.io/sheyaln/sabokit-runner:<tag>`. It bundles ansible-core + four collections + the Terraform CLI + the entire `platform/` tree at the matching repo tag. Published on every `v*` tag push by `.github/workflows/runner-publish.yml`.

`scripts/sabokit-runner.sh` is the consumer-facing wrapper for the ansible side. Hides the docker invocation behind friendly flags.

## Install

```
curl -fsSL https://raw.githubusercontent.com/sheyaln/sabokit/v3.0.0/scripts/sabokit-runner.sh \
  -o /usr/local/bin/sabokit-runner && chmod +x /usr/local/bin/sabokit-runner
```

Image tag tracks the wrapper version. `sabokit-runner --image v2.16.2` pulls a different tag (testing pre-release / pinning a known-good).

## Recipes

| intent | command |
| --- | --- |
| full deploy | `sabokit-runner` |
| redeploy one app | `sabokit-runner --apps outline` |
| redeploy several apps | `sabokit-runner --apps outline,n8n` |
| fast (skip base layer) | `sabokit-runner --apps outline --no-base` |
| reprovision one server | `sabokit-runner --servers tools-prod` |
| base only, one host | `sabokit-runner --base --servers authentik-prod` |
| rotate secrets, all hosts | `sabokit-runner --rotate-secrets` |
| rotate secrets, one host | `sabokit-runner --rotate-secrets --servers tools-prod` |
| rotate secrets for one app | `sabokit-runner --apps outline` (see note) |
| dry-run any of the above | append `--check` |
| inspect the docker invocation | append `--dry-run` |
| with consumer overlay | prepend `--overlay ansible-local` |

Targeting flags compose: `--apps outline,n8n --servers tools-prod --check` plans a per-host two-app redeploy with diff output.

### Per-app secret rotation note

Ansible tag semantics are union, not intersection — `--rotate-secrets --apps outline` runs *every* secrets task **and** every outline task, not just outline's secrets. For per-app rotation, run `--apps outline` directly: the role re-fetches the secret, re-renders the env file, and the restart handler fires when content changes. Cost is one full role re-run, which is idempotent and seconds-fast.

For host-scoped rotation across every enabled app on that host, `--rotate-secrets --servers tools-prod` is the right shape.

### Consumer overlays

`--overlay DIR` mounts a consumer-side directory at `/consumer:ro`. Two conventions:

- `DIR/extensions.yml` (if present) runs after upstream's `site.yml` in the same ansible process — shared facts cache, shared SSH connections. Use for gap apps that don't yet have an upstream bundle.
- `DIR/roles/` is appended to `ANSIBLE_ROLES_PATH` after upstream roles. Upstream wins on name collision. Consumers wanting to override an upstream role should fork the bundle.

`DIR/group_vars/` and `DIR/host_vars/` are picked up by ansible's normal precedence rules.

## Raw docker invocation

What the wrapper builds. Use directly if you don't want the wrapper on your path.

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

`sabokit-runner --dry-run [flags...]` prints the exact docker invocation it would run — useful for porting to CI/CD or one-off debugging.

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

The sabokit CLI (Go+Wails deploy wizard) wraps this and sets the workdir itself.

## Scaleway state-backend credentials

Terraform reads Scaleway creds from env. Pass via `-e` or `--env-file`:

| env var | purpose |
| --- | --- |
| `SCW_ACCESS_KEY` | API key for state R/W + resource ops |
| `SCW_SECRET_KEY` | matching secret |
| `SCW_DEFAULT_ORGANIZATION_ID` | org for default provider |
| `SCW_DEFAULT_PROJECT_ID` | project for default provider |

Image is also what `sabokit-manager` (Go+Wails deploy wizard) shells out to.
