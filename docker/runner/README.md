# Ansible runner image

Published as `ghcr.io/sheyaln/sabokit-runner:<tag>` on every `v*` tag push by `.github/workflows/runner-publish.yml`.

## What's in it

Ansible-core + the four collections every bundle depends on (`community.docker`, `community.general`, `ansible.posix`, `scaleway.scaleway`) + the entire `platform/` tree at the matching repo tag.

That's it. No terraform, no consumer-template, no secrets. TF state stays on the consumer side.

## Consumer pattern

```
docker run --rm \
  -v "$PWD/env:/env:ro" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
  ghcr.io/sheyaln/sabokit-runner:v2.9.x \
  site.yml -i /env/inventory.ini -e @/env/enabled_apps.json
```

`/env` is your call. The image expects: an inventory file and an `enabled_apps.json` produced by `terraform output -json enabled_apps`. SSH agent forwarding is the cleanest way to hand it host credentials; mounting a keyfile and `--key-file` also works.

Workdir is `/opt/sabokit/platform/ansible`. Entrypoint is `ansible-playbook`, so positional args are playbook + flags.

## Why this exists

So consumers stop installing ansible-core + four collections + python deps on every workstation that touches the platform. The runner image is also what `sabokit-manager` (planned Go+Wails wizard) shells out to.
