# platform/infra/ansible

The bootstrap layer every consumer of `sabokit` runs on its hosts before deploying any app bundle. App bundles (`platform/application/<name>/ansible/`) `import_role` from here for Docker, Traefik labels, secret fetching, and the monitoring agent.

## What's here

| Role | Purpose |
|------|---------|
| [`docker`](roles/docker/) | Install Docker Engine + Compose plugin with safe log-rotation defaults. |
| [`fail2ban`](roles/fail2ban/) | Install Fail2ban so other roles can drop filter/jail configs. |
| [`log-management`](roles/log-management/) | Cap journald disk usage and install a baseline logrotate policy. |
| [`unattended-upgrades`](roles/unattended-upgrades/) | Configure automatic security updates with optional email + webhook hooks. |
| [`ufw`](roles/ufw/) | Deny-by-default firewall opening 22/80/443 plus consumer-supplied rules. |
| [`scw-secrets`](roles/scw-secrets/) | Install Scaleway CLI and helpers so containers fetch secrets from Scaleway Secret Manager into tmpfs at start-up. The contract every app bundle uses for secrets. |
| [`traefik`](roles/traefik/) | Traefik v3 reverse proxy with Let's Encrypt, Prometheus metrics, file-provider middlewares (security headers, rate limit, Authentik forward-auth), and Fail2ban filters. |
| [`monitoring-agent`](roles/monitoring-agent/) | Per-host node-exporter + cAdvisor + Grafana Alloy (logs to Loki). Backend-agnostic. |

Each role is self-contained: defaults, tasks, templates, handlers, meta, README.

## Dependency graph

```
docker ─────────────────┬─► traefik
                        └─► monitoring-agent

fail2ban ───────────────► traefik   (optional; traefik drops filters only if fail2ban is present)

log-management            (independent)
unattended-upgrades       (independent)
ufw                       (independent)
scw-secrets               (independent — consumed by app roles via include_role)
```

Declared dependencies in `meta/main.yml` will auto-pull where listed (notably `traefik` and `monitoring-agent` both depend on `docker`).

## Required Ansible collections

```yaml
# requirements.yml
collections:
  - name: community.docker
  - name: community.general
```

## Minimal bootstrap playbook

A consumer's `site.yml` for a single application host:

```yaml
- name: Bootstrap application host
  hosts: apps
  become: true
  roles:
    - role: log-management
    - role: unattended-upgrades
      vars:
        unattended_upgrades_automatic_reboot: true
        unattended_upgrades_automatic_reboot_time: "03:30"

    - role: ufw
      vars:
        ufw_extra_rules: []   # add per-host extras here

    - role: docker
    - role: fail2ban
    - role: traefik
      vars:
        traefik_acme_email: "ops@example.org"
        traefik_authentik_outpost_url: "https://auth.example.org/outpost.goauthentik.io/auth/traefik"

    - role: scw-secrets
      vars:
        scw_secrets_project_id: "{{ scaleway_project_id }}"
        # access_key/secret_key default to env vars SCW_SECRETS_ACCESS_KEY / SCW_SECRETS_SECRET_KEY

    - role: monitoring-agent
      vars:
        monitoring_host_label: "apps-prod"
        monitoring_environment: "production"
        monitoring_loki_push_url: "https://loki.example.org/loki/api/v1/push"
        monitoring_scraper_cidrs:
          - "10.0.0.5/32"   # central prometheus

- import_playbook: ../application/outline/ansible/playbook.yml
- import_playbook: ../application/steward/ansible/playbook.yml
```

## Conventions

- **Service users**: long-lived roles run under unprivileged service accounts where the upstream image supports it (`scw-secrets` runs as `scw-secrets:scw-secrets`; node-exporter and cAdvisor run as `root` only because they need it).
- **Install paths**: roles install under `/opt/<role-name>/` by default. Override `<role>_dir` to relocate.
- **Compose-managed services**: every long-running service (traefik, monitoring-agent) is a docker-compose project rendered from a `.j2` template. To debug, `cd /opt/<role>` and use `docker compose logs`.
- **Secrets**: app bundles never bake credentials into env files. They register a mapping with `scw-secrets/deploy-mapping` and reference `/run/secrets/<name>` in their compose service.
- **Required variables are asserted** at the top of `tasks/main.yml`. Missing required values fail loud, not silently.

## Versioning

`platform/infra/ansible` is versioned together with the rest of the repo (see `ARCHITECTURE.md`'s "Versioning" section). Consumers pin via a repo-level tag. Breaking changes to a role's variable surface bump the major version of the entire blueprint.
