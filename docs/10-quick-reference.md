---
layout: default
title: "Part 10: Quick Reference"
---

# Part 10: Quick Reference

Tables and commands for fast lookup.

## 10.1 Server Reference

| Server | Public IP | Private IP | Purpose |
|--------|-----------|------------|---------|
| tools-prod | 192.0.2.10 | 10.0.0.3 | Production applications |
| management | 192.0.2.20 | 10.0.0.5 | Monitoring, automation |
| authentik-prod | 192.0.2.30 | 10.0.0.2 | SSO/Identity |

> Note: IPs shown are RFC 5737 documentation examples. Replace with your actual server IPs.

## 10.2 Application URLs

| Application | URL | Server |
|-------------|-----|--------|
| Authentik | https://gateway.example.org | authentik-prod |
| Decidim | https://voting.example.org | tools-prod |
| EspoCRM | https://espo.example.org | tools-prod |
| Outline | https://wiki.example.org | tools-prod |
| Nextcloud | https://cloud.example.org | tools-prod |
| Grafana | https://grafana.example.cc | management |
| Zabbix | https://zabbix.example.cc | management |
| Wobbler | https://wobbler.example.cc | management |

> Note: Replace `example.org` and `example.cc` with your actual domains.

## 10.3 Port Reference

| Port | Service | Access |
|------|---------|--------|
| 22 | SSH | Public |
| 80 | HTTP | Public (redirects to 443) |
| 443 | HTTPS | Public |
| 3000 | Grafana | Via Traefik |
| 3100 | Loki | Private network |
| 5432 | PostgreSQL | Private network |
| 8080 | cAdvisor | Private network |
| 9090 | Prometheus | Internal only |
| 9100 | Node Exporter | Private network |
| 10051 | Zabbix Server | Private network |

## 10.4 Ansible Tags

| Tag | Playbook | Deploys |
|-----|----------|---------|
| docker | all | Docker runtime |
| traefik | all | Traefik reverse proxy |
| security | all | UFW, Fail2ban |
| monitoring-exporters | all | Node Exporter, cAdvisor, Alloy |
| monitoring-stack | management | Grafana, Prometheus, Loki, Zabbix |
| authentik | authentik | Authentik SSO |
| decidim | tools-prod | Decidim |
| outline | tools-prod | Outline wiki |
| espocrm | tools-prod | EspoCRM |
| nextcloud-suite | tools-prod | Nextcloud + OnlyOffice |
| leantime | tools-prod | Leantime |
| wobbler | management | Script server |
| n8n | management | n8n automation |

## 10.5 Secret Names

| Secret | Contains | Used By |
|--------|----------|---------|
| postgres-{app}-credentials | DB host, user, pass | Application |
| authentik-app-{slug} | OAuth client_id, client_secret | Application |
| smtp-config | SMTP host, user, pass | All apps with email |
| authentik-secret-key | Authentik internal key | Authentik |
| outline-secret-key | Outline encryption key | Outline |
| decidim-secret-key-base | Decidim session key | Decidim |

## 10.6 User Groups

| Group | Access Level |
|-------|--------------|
| admin | Full access to all applications |
| union-delegate | Most applications, limited admin |
| union-secretary-treasurer | Financial applications |
| union-member | Member-facing applications |

## 10.7 Directory Structure (Servers)

```
/opt/
├── traefik/           # Reverse proxy
├── outline/           # Wiki
├── decidim/           # Voting
├── nextcloud/         # File sharing
├── espocrm/           # CRM
├── monitoring/        # Grafana, Prometheus, Loki (management)
├── exporters/         # Node Exporter, cAdvisor, Alloy
└── wobbler/           # Script server (management)
```

## 10.8 Common Commands

### SSH

```bash
ssh tools-prod
ssh management
ssh authentik-prod
```

### Docker

```bash
docker ps                           # List containers
docker logs {container} --tail 50   # View logs
docker restart {container}          # Restart
docker stats                        # Resource usage
docker system prune -af             # Clean up
```

### Ansible

```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags {tag}
ansible-playbook playbook-tools-prod.yml -i inventory.ini --list-tags
ansible-playbook playbook-tools-prod.yml -i inventory.ini --check --tags {tag}
```

### Terraform

```bash
terraform init
terraform plan
terraform apply
terraform state list
```

### Debug Secrets

```bash
ansible localhost -m debug -a "msg={% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'secret-name') | b64decode }}{% endraw %}"
```

## 10.9 File Locations

### Local (Your Machine)

```
sabokit/
├── terraform-scaleway-infra/    # Cloud infrastructure
├── terraform-authentik/         # SSO configuration
├── terraform-grafana/           # Monitoring dashboards
├── ansible-vps/                 # Server configuration
│   ├── inventory.ini
│   ├── playbook-*.yml
│   ├── group-vars/
│   └── roles/
└── docs/                        # This documentation
```

### Remote (Servers)

```
/opt/{app}/
├── docker-compose.yml
└── .env

/var/log/
├── traefik/
└── fail2ban.log
```

## 10.10 Environment Variables

```bash
# Required
export SCW_ACCESS_KEY="your-access-key"
export SCW_SECRET_KEY="your-secret-key"
export SCW_DEFAULT_PROJECT_ID="your-project-id"
export SCW_DEFAULT_REGION="fr-par"

# Terraform
export TF_VAR_access_key="${SCW_ACCESS_KEY}"
export TF_VAR_secret_key="${SCW_SECRET_KEY}"
export TF_VAR_project_id="${SCW_DEFAULT_PROJECT_ID}"

# S3 Backend
export AWS_ACCESS_KEY_ID="${SCW_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${SCW_SECRET_KEY}"

# GitHub
export GITHUB_USERNAME="your-github-username"
export GITHUB_TOKEN="your-github-token"
```

## 10.11 OIDC Endpoints

Base URL: `https://gateway.example.org`

| Endpoint | Path |
|----------|------|
| Authorization | /application/o/authorize/ |
| Token | /application/o/token/ |
| Userinfo | /application/o/userinfo/ |
| End Session | /application/o/{slug}/end-session/ |
| Discovery | /application/o/{slug}/.well-known/openid-configuration |

## 10.12 Emergency Contacts

| Issue | Action |
|-------|--------|
| Scaleway infrastructure | https://console.scaleway.com > Support |
| Server down | Check Scaleway Console, use emergency console |
| All logins failing | Check authentik-prod first |
| Application error | Check container logs, redeploy |

## 10.13 Backup Locations

| Data | Location | Retention |
|------|----------|-----------|
| PostgreSQL | Scaleway managed backups | 3 days |
| Application data | S3 {project}-appdata-prod-0 | Configurable |
| Terraform state | S3 {project}-terraform-state-prod-0 | Versioned |
| ACME certificates | S3 {project}-traefik-acme-prod-0 | Indefinite |

> Note: Replace `{project}` with your project name prefix.
