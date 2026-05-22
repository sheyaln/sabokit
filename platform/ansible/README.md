# platform/ansible

Orchestration layer for the platform's Ansible side. Role *definitions* live next to the bundles they belong to (`platform/base/ansible/roles/`, `platform/apps/<name>/ansible/roles/`, `platform/identity/ansible/roles/`); this directory holds the *playbooks* that wire them together.

## Files

| File | Purpose |
|------|---------|
| [`ansible.cfg`](./ansible.cfg) | `roles_path` enumerating every bundle's `ansible/roles/` dir. When you add a new app, append it. |
| [`bootstrap.yml`](./bootstrap.yml) | Prereqs every host needs once: docker, traefik, fail2ban, scw-secrets, monitoring-agent, ufw, log-management, unattended-upgrades. Tag: `bootstrap`. |
| [`apps.yml`](./apps.yml) | One `import_playbook` per app, conditional on `enabled_apps.<name>` being non-null. Tag: `apps`, plus per-app tag. |
| [`site.yml`](./site.yml) | `bootstrap.yml` + `apps.yml`. The default entry point. |

## Two-stage deploy model

App roles assume bootstrap is already done — they assert prereqs (e.g. `docker info` exits 0) but do NOT install them. Splitting bootstrap out means:

- **Fresh host**: `ansible-playbook site.yml` — provisions prereqs and ships apps.
- **Routine app redeploy**: `ansible-playbook site.yml --skip-tags bootstrap` — seconds, not minutes.
- **One app only**: `ansible-playbook site.yml --tags outline`.

## How the consumer drives this

Consumers don't usually invoke this dir directly. They use `consumer-template/environments/<env>/deploy.sh`, which:

1. Runs `terraform apply`.
2. Writes `terraform output -json enabled_apps > .enabled_apps.json`.
3. Calls `ansible-playbook platform/ansible/site.yml -e @.enabled_apps.json -i inventory.ini`.

Each app's `import_playbook` in `apps.yml` is gated on `enabled_apps.<name> is not none`, so disabled apps are silently skipped.

## Adding a new app

1. Ship the app bundle under `platform/apps/<new-app>/`.
2. Append its `ansible/roles` dir to `ansible.cfg`'s `roles_path`.
3. Add an `import_playbook` block in `apps.yml` with the right `when:` and `vars:`.

## Required collections

```bash
ansible-galaxy collection install community.docker community.general scaleway.scaleway
```
