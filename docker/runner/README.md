# Ansible runner image + fc-runner wrapper

The runner image is `ghcr.io/sheyaln/sabokit-runner:<tag>`. It bundles ansible-core + four collections + the entire `platform/` tree at the matching repo tag. Published on every `v*` tag push by `.github/workflows/runner-publish.yml`.

`scripts/fc-runner.sh` is the consumer-facing wrapper. Hides the docker invocation behind friendly flags.

## Install

```
curl -fsSL https://raw.githubusercontent.com/sheyaln/sabokit/v2.17.0/scripts/fc-runner.sh \
  -o /usr/local/bin/fc-runner && chmod +x /usr/local/bin/fc-runner
```

Image tag tracks the wrapper version. `fc-runner --image v2.16.2` pulls a different tag (testing pre-release / pinning a known-good).

## Recipes

| intent | command |
| --- | --- |
| full deploy | `fc-runner` |
| redeploy one app | `fc-runner --apps outline` |
| redeploy several apps | `fc-runner --apps outline,n8n` |
| fast (skip base layer) | `fc-runner --apps outline --no-base` |
| reprovision one server | `fc-runner --servers tools-prod` |
| base only, one host | `fc-runner --base --servers authentik-prod` |
| rotate secrets, all hosts | `fc-runner --rotate-secrets` |
| rotate secrets, one host | `fc-runner --rotate-secrets --servers tools-prod` |
| rotate secrets for one app | `fc-runner --apps outline` (see note) |
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

`fc-runner --dry-run [flags...]` prints the exact docker invocation it would run — useful for porting to CI/CD or one-off debugging.

## Image scope

Built on `python:3.12-slim`. Contains:

- ansible-core (pinned via `ANSIBLE_CORE_VERSION` build arg)
- collections: `community.docker`, `community.general`, `ansible.posix`, `scaleway.scaleway`
- python deps: `requests`, `jmespath`, `passlib`, `docker`
- the full `platform/` tree at the matching repo tag (apps, base, identity, bootstrap)

Not in the image: terraform, consumer-template, secrets, TF state. State stays on the consumer side.

Entrypoint: `ansible-playbook`. Workdir: `/opt/sabokit/platform/ansible`. Image is also what `sabokit-manager` (Go+Wails deploy wizard) shells out to.
