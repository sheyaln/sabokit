---
layout: default
title: "Part 3: Configuration Management"
---

# Part 3: Configuration Management (Ansible)

The `ansible-vps/` directory contains Ansible playbooks and roles that configure servers and deploy applications.

## 3.1 What is Ansible?

Ansible is a tool that automates server configuration. Instead of SSH-ing into a server and running commands manually, you write YAML files that describe what you want, and Ansible makes it happen.

Without Ansible:
1. SSH into server
2. Run `apt update && apt install docker.io`
3. Edit config files manually
4. Repeat for every server
5. Forget what you did six months later

With Ansible:
1. Write a playbook that describes desired state
2. Run `ansible-playbook` command
3. Ansible SSHs into servers and runs everything
4. Playbook serves as documentation
5. Run again anytime to ensure consistency

Ansible is **idempotent**: running the same playbook twice produces the same result. If Docker is already installed, Ansible skips installing it again.

Documentation: https://docs.ansible.com/ansible/latest/getting_started/index.html

## 3.2 Directory Structure

```
ansible-vps/
├── ansible.cfg              # Ansible settings
├── inventory.ini            # List of servers to manage
├── playbook-tools-prod.yml  # Playbook for the tools server
├── playbook-management.yml  # Playbook for the management server
├── playbook-authentik.yml   # Playbook for the authentik SSO server
├── playbook-wazuh.yml       # Wazuh deployment (WIP)
├── group-vars/              # Variables organized by application
│   ├── all.yml              # Variables available to all playbooks
│   ├── core.yml             # Core infrastructure variables
│   ├── monitoring.yml       # Monitoring-specific variables
│   ├── outline.yml          # Outline wiki variables
│   └── [etc].yml
├── roles/                   # Reusable configuration units
│   ├── core/                # Core infrastructure
│   │   ├── docker/
│   │   ├── traefik/
│   │   ├── ufw/
│   │   └── fail2ban/
│   ├── monitoring/
│   │   ├── exporters/
│   │   └── stack/
│   ├── management/
│   │   ├── wobbler/
│   │   └── wazuh/
│   └── tools/               # Application roles
│       ├── decidim/
│       ├── outline/
│       └── espocrm/
└── includes/
    └── security-common.yml
```

### Role Structure

Each role follows a standard layout:

```
roles/tools/outline/
├── tasks/
│   └── main.yml         # What to do (the actual work)
├── templates/
│   ├── docker-compose.yml.j2   # Jinja2 template files
│   └── env.j2
├── files/               # Static files copied as-is
├── handlers/
│   └── main.yml         # Actions triggered by changes (e.g., restart service)
└── defaults/
    └── main.yml         # Default variable values
```

| Directory | Purpose |
|-----------|---------|
| tasks/ | YAML files with steps to execute |
| templates/ | Files with variables that get filled in (`.j2` = Jinja2 template) |
| files/ | Static files copied to server unchanged |
| handlers/ | Actions triggered by "notify" (e.g., restart a service after config change) |
| defaults/ | Default values for variables (can be overridden) |

## 3.3 Inventory

`inventory.ini` lists the servers Ansible manages. Copy `inventory.ini.example` and update with your actual IPs:

```ini
[management]
192.0.2.20 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519

[tools-prod]
192.0.2.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519

[authentik-prod]
192.0.2.30 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

> Note: IPs shown are RFC 5737 documentation examples. Replace with your actual server IPs.

The brackets define groups. Playbooks target groups (e.g., `hosts: tools-prod`).

## 3.4 Running Playbooks

Command format:
```bash
ansible-playbook <PLAYBOOK> -i inventory.ini --tags <TAG>
```

Always use tags. Don't run the entire playbook unless deploying for the first time or recovering from a catastrophe.

Examples:
```bash
# Deploy Outline wiki
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags outline

# Deploy Traefik reverse proxy
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags traefik

# Deploy monitoring stack
ansible-playbook playbook-management.yml -i inventory.ini --tags monitoring-stack
```

List available tags:
```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --list-tags
```

Dry run (shows what would change without doing it):
```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags outline --check
```

## 3.5 ansible.cfg

```ini
[defaults]
inventory = inventory.ini
stdout_callback=debug
stderr_callback=debug

[privilege_escalation]
become = false

[ssh_connection]
ssh_args = -o ForwardAgent=yes
```

### What is "become"?

`become` means "become another user" - typically root. It's Ansible's way of running commands with `sudo`.

- `become = false` (default): Commands run as the SSH user (`ubuntu`)
- `become = true`: Commands run with sudo privileges

You need `become: true` when:
- Installing packages (`apt install`)
- Modifying system files (`/etc/...`)
- Managing system services (`systemctl`)
- Anything requiring root permissions

You don't need it for:
- Creating files in user directories
- Running Docker commands (ubuntu user is in docker group)
- Most application deployment tasks

Each play or task can override the default with `become: true`.

## 3.6 Group Variables

Variables are stored in `group-vars/`. Ansible loads them based on playbook context.

### all.yml

Variables available everywhere:

```yaml
traefik_email: infra@example.org

# Read from environment variables
github_username: "{% raw %}{{ lookup('env', 'GITHUB_USERNAME') }}{% endraw %}"
github_token: "{% raw %}{{ lookup('env', 'GITHUB_TOKEN') }}{% endraw %}"

scaleway_access_key: "{% raw %}{{ lookup('env', 'SCW_ACCESS_KEY') }}{% endraw %}"
scaleway_secret_key: "{% raw %}{{ lookup('env', 'SCW_SECRET_KEY') }}{% endraw %}"

# Read from Scaleway Secret Manager
smtp_host: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'smtp-config') | b64decode | from_json).smtp_host }}{% endraw %}"
smtp_port: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'smtp-config') | b64decode | from_json).smtp_port }}{% endraw %}"

# Domain mapping based on server
environment_domains:
  tools: "example.org"        # Production applications
  staging: "example.com"      # Staging environment
  management: "example.cc"    # Monitoring and automation
```

### Application-specific (outline.yml)

```yaml
# Database credentials from Scaleway Secret Manager
outline_db_creds: "{% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'postgres-outline-credentials') | b64decode | from_json }}{% endraw %}"

PG_DB: "{% raw %}{{ outline_db_creds.dbname }}{% endraw %}"
PG_USER: "{% raw %}{{ outline_db_creds.username }}{% endraw %}"
PG_PASS: "{% raw %}{{ outline_db_creds.password }}{% endraw %}"
PG_HOST: "{% raw %}{{ outline_db_creds.host }}{% endraw %}"
PG_PORT: "{% raw %}{{ outline_db_creds.port }}{% endraw %}"

# Application secrets
OUTLINE_SECRET_KEY: "{% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'outline-secret-key') | b64decode }}{% endraw %}"
OUTLINE_URL: "https://wiki.example.org"

# OAuth from Authentik (stored in Scaleway by Terraform)
OIDC_CLIENT_ID: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'authentik-app-outline') | b64decode | from_json).client_id }}{% endraw %}"
OIDC_CLIENT_SECRET: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'authentik-app-outline') | b64decode | from_json).client_secret }}{% endraw %}"
OIDC_AUTH_URI: https://gateway.example.org/application/o/authorize/
OIDC_TOKEN_URI: https://gateway.example.org/application/o/token/
OIDC_USERINFO_URI: https://gateway.example.org/application/o/userinfo/
```

## 3.7 Playbook Structure

A playbook is a list of "plays". Each play targets hosts and applies roles.

From `playbook-tools-prod.yml`:

```yaml
---
- name: Configure Tools host - Docker Runtime
  hosts: tools-prod          # Target server group
  tags:                      # Tags for selective running
    - core
    - docker
  become: true               # Run with sudo
  vars_files:                # Load these variable files
    - group-vars/all.yml
    - group-vars/core.yml
  roles:                     # Apply these roles
    - core/docker

- name: Configure Tools host - Traefik
  hosts: tools-prod
  tags: traefik
  become: true
  vars_files:
    - group-vars/all.yml
    - group-vars/traefik.yml
  roles:
    - core/traefik

- name: Configure Tools host - Outline
  hosts: tools-prod
  tags: outline
  become: true
  vars_files:
    - group-vars/all.yml
    - group-vars/outline.yml
  roles:
    - tools/outline
```

## 3.8 Role Example: Outline

### tasks/main.yml

```yaml
---
- name: Ensure Outline directory
  ansible.builtin.file:
    path: /opt/outline
    state: directory
    mode: '0755'
    owner: ubuntu
    group: ubuntu

- name: Generate docker-compose file
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: /opt/outline/docker-compose.yml
    mode: '0644'
    owner: ubuntu
    group: ubuntu

- name: Render environment file
  ansible.builtin.template:
    src: env.j2
    dest: /opt/outline/.env
    mode: '0600'
    owner: ubuntu
    group: ubuntu

- name: Ensure Outline containers are running
  community.docker.docker_compose_v2:
    project_src: /opt/outline
    state: present
```

### templates/docker-compose.yml.j2

The `.j2` extension means Jinja2 template. Variables like `{% raw %}{{ tools_domain }}{% endraw %}` get replaced:

```yaml
services:
  outline:
    image: docker.getoutline.com/outlinewiki/outline:latest
    container_name: outline
    restart: always
    
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.outline.rule=Host(`wiki.{% raw %}{{ tools_domain }}{% endraw %}`)"
      - "traefik.http.routers.outline.entrypoints=websecure"
      - "traefik.http.routers.outline.tls.certresolver=le"
      - "traefik.docker.network=traefik"
    
    environment:
      DATABASE_URL: postgres://${PG_USER}:${PG_PASS}@${PG_HOST}:${PG_PORT}/${PG_DB}
      SECRET_KEY: ${SECRET_KEY}
    
    networks:
      - traefik
      - outline_network

networks:
  traefik:
    external: true
  outline_network:
    driver: bridge
```

### templates/env.j2

```
PG_DB={% raw %}{{ PG_DB }}{% endraw %}
PG_USER={% raw %}{{ PG_USER }}{% endraw %}
PG_PASS={% raw %}{{ PG_PASS }}{% endraw %}
PG_HOST={% raw %}{{ PG_HOST }}{% endraw %}
PG_PORT={% raw %}{{ PG_PORT }}{% endraw %}

SECRET_KEY={% raw %}{{ OUTLINE_SECRET_KEY }}{% endraw %}

OIDC_CLIENT_ID={% raw %}{{ OIDC_CLIENT_ID }}{% endraw %}
OIDC_CLIENT_SECRET={% raw %}{{ OIDC_CLIENT_SECRET }}{% endraw %}
```

## 3.9 Core Roles

### docker

Installs Docker, configures daemon, adds ubuntu user to docker group.

```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags docker
```

### traefik

Deploys Traefik reverse proxy with automatic Let's Encrypt certificates.

```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags traefik
```

Creates:
- `/opt/traefik/docker-compose.yml`
- `/opt/traefik/.env`
- Fail2ban filters

### ufw

Configures firewall. Default: deny incoming, allow SSH/HTTP/HTTPS.

```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags security
```

### fail2ban

Blocks IPs after failed login attempts.

## 3.10 Monitoring Roles

### exporters

Deploys metrics collectors on each server:
- Node Exporter (host metrics)
- cAdvisor (container metrics)
- Alloy (log shipping)

```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags monitoring-exporters
```

### stack

Deploys full monitoring on management server:
- Grafana (dashboards)
- Prometheus (metrics database)
- Loki (logs database)
- Zabbix (infrastructure monitoring)

```bash
ansible-playbook playbook-management.yml -i inventory.ini --tags monitoring-stack
```

## 3.11 Application Deployment Pattern

Every application follows the same pattern:

1. Create directory at `/opt/{appname}/`
2. Deploy `docker-compose.yml` from template
3. Deploy `.env` with secrets from template
4. Start containers

Directory structure on server:
```
/opt/
├── traefik/
│   ├── docker-compose.yml
│   └── .env
├── outline/
│   ├── docker-compose.yml
│   └── .env
├── decidim/
│   ├── docker-compose.yml
│   └── .env
└── ...
```

All applications:
- Connect to the `traefik` Docker network
- Have Traefik labels for routing
- Store secrets in `.env` files (mode 0600)
- Use `ubuntu:ubuntu` ownership

## 3.12 Adding a New Application

1. Create role directory:
```bash
mkdir -p roles/tools/myapp/{tasks,templates}
```

2. Create `tasks/main.yml`:
```yaml
---
- name: Ensure MyApp directory
  ansible.builtin.file:
    path: /opt/myapp
    state: directory
    mode: '0755'
    owner: ubuntu
    group: ubuntu

- name: Deploy docker-compose file
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: /opt/myapp/docker-compose.yml
    mode: '0644'

- name: Render environment file
  ansible.builtin.template:
    src: env.j2
    dest: /opt/myapp/.env
    mode: '0600'

- name: Ensure containers are running
  community.docker.docker_compose_v2:
    project_src: /opt/myapp
    state: present
```

3. Create `templates/docker-compose.yml.j2` and `templates/env.j2`

4. Create `group-vars/myapp.yml` with database credentials, OAuth config, etc.

5. Add play to playbook:
```yaml
- name: Configure Tools host - MyApp
  hosts: tools-prod
  tags: myapp
  become: true
  vars_files:
    - group-vars/all.yml
    - group-vars/myapp.yml
  roles:
    - tools/myapp
```

6. Run:
```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags myapp
```

## 3.13 Debugging

Verbose output (shows what Ansible is doing):
```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags outline -vvv
```

Check mode (dry run):
```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags outline --check
```

Run single command on server:
```bash
ansible tools-prod -m command -a "docker ps"
```

Test secret access:
```bash
ansible localhost -m debug -a "msg={% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'outline-secret-key') | b64decode }}{% endraw %}"
```

## 3.14 Further Reading

- Ansible Getting Started: https://docs.ansible.com/ansible/latest/getting_started/index.html
- Ansible Playbook Guide: https://docs.ansible.com/ansible/latest/playbook_guide/index.html
- Jinja2 Templates: https://jinja.palletsprojects.com/en/3.1.x/templates/
