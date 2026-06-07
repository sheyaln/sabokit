# platform/ansible

Orchestration layer for the platform's Ansible side. Role *definitions* live next to the bundles they belong to (`platform/infra/ansible/roles/`, `platform/application/<name>/ansible/roles/`, `platform/identity/ansible/roles/`); this directory holds the *playbooks* that wire them together.

## Files

| File | Purpose |
|------|---------|
| [`ansible.cfg`](./ansible.cfg) | `roles_path` enumerating every bundle's `ansible/roles/` dir. When you add a new app, append it. |
| [`bootstrap.yml`](./bootstrap.yml) | Prereqs every host needs once: docker, traefik, fail2ban, scw-secrets, monitoring-agent, ufw, log-management, unattended-upgrades. Tag: `bootstrap`. |
| [`host-services.yml`](./host-services.yml) | One `import_playbook` per per-host watcher instance (diun/autoheal/wazuh-agent). Tag: `host-services`. **Auto-generated** by `scripts/gen_apps_yml.py`. |
| [`operations.yml`](./operations.yml) | One `import_playbook` per operations service (loki/prometheus/grafana/wazuh/protonmail-bridge). Tag: `operations`, plus per-service tag. **Auto-generated.** |
| [`application.yml`](./application.yml) | One `import_playbook` per app, conditional on `enabled_apps.<name>` being non-null. Tag: `application`, plus per-app tag. **Auto-generated.** |
| [`site.yml`](./site.yml) | `bootstrap.yml` + `host-services.yml` + `operations.yml` + `application.yml`. The default entry point. |

## Two-stage deploy model

App roles assume bootstrap is already done — they assert prereqs (e.g. `docker info` exits 0) but do NOT install them. Splitting bootstrap out means:

- **Fresh host**: `ansible-playbook site.yml` — provisions prereqs and ships apps.
- **Routine app redeploy**: `ansible-playbook site.yml --skip-tags bootstrap` — seconds, not minutes.
- **One app only**: `ansible-playbook site.yml --tags outline`.

## How the consumer drives this

Consumers don't usually invoke this dir directly. They use the per-layer scripts (`consumer-template/scripts/{infra,identity,operations,application}.sh`, or `up.sh`), each of which:

1. Runs `terraform apply` for its layer.
2. Writes `terraform output -json enabled_apps > .enabled_apps.json`.
3. Calls `ansible-playbook ansible-local/site.yml -e @.enabled_apps.json -i inventory.ini --tags <layer>`.

Each app's `import_playbook` is gated on `enabled_apps.<name> is not none`, so disabled apps are silently skipped.

## `[secrets]` tag — rotation path

Tasks tagged `[secrets]` form the secret-rotation path — running `ansible-playbook ... --tags secrets` re-fetches secrets, re-renders env/config files, and the restart handler fires when content changes. Apply at host scope via `--limit`; per-app scope via `--tags secrets,<app-slug>` is UNION not intersection — that runs all of `<app>` AND all secrets tasks, which is fine but heavier. For true per-app rotation, just run `--tags <app-slug>` (the full role is idempotent and re-fetches secrets along the way).

## Adding a new app

1. Ship the app bundle under `platform/application/<new-app>/`.
2. Append its `ansible/roles` dir to `ansible.cfg`'s `roles_path`.
3. Run `python3 scripts/gen_apps_yml.py` to regenerate `application.yml` from the bundle's `ansible` output — never hand-edit the generated playbooks.

## Required collections

```bash
ansible-galaxy collection install community.docker community.general scaleway.scaleway
```
