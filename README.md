![Federated Commons](/images/fed-commons-banner.png)

Open-source infrastructure for unions and worker-led organizations. Deploy your own self-hosted suite of collaboration tools with enterprise-grade identity management, monitoring, and automation.

## What's Included

- **Identity & Access**: Authentik SSO with MFA, social login (Google, Apple), and fine-grained access control
- **Collaboration Tools**: Decidim (participatory democracy), Outline (wiki), Nextcloud (file sharing), and more
- **Monitoring**: Grafana, Prometheus, Loki, Zabbix - full observability stack
- **Automation**: n8n workflows, Wobbler script runner, automated backups
- **Security**: Fail2ban, UFW, Wazuh SIEM, automatic security updates

## Architecture

```
sabokit/
├── config/              # Central configuration (project.yml)
├── ansible/             # Server configuration & app deployment
├── terraform/
│   ├── infrastructure/  # Scaleway VPS, PostgreSQL, S3, DNS
│   ├── authentik/       # SSO configuration, flows, apps
│   └── grafana/         # Dashboards and alerts
├── docs/                # Documentation
└── scripts/             # Utility scripts
```

## Quick Start

### 1. Configure

```bash
# Copy and edit the central configuration
cp config/project.yml.example config/project.yml
# Edit with your domains, org name, etc.
```

### 2. Provision Infrastructure (Terraform)

```bash
cd terraform/infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit with Scaleway credentials
terraform init && terraform apply
```

### 3. Deploy Applications (Ansible)

```bash
cd ansible
cp inventory.ini.example inventory.ini
# Edit with your server IPs

# Deploy in order:
ansible-playbook playbook-authentik.yml -i inventory.ini
ansible-playbook playbook-management.yml -i inventory.ini
ansible-playbook playbook-tools-prod.yml -i inventory.ini
```

See [docs/](docs/) for detailed instructions.

## Staging Environment

Save money by running staging on a single VPS with local PostgreSQL:

```bash
# Start staging
./ansible/scripts/staging-control.sh start

# Deploy to staging
ansible-playbook ansible/playbook-staging.yml -i inventory.ini

# Stop when done (Decreases billed amount!)
./ansible/scripts/staging-control.sh stop
```

## Cost Estimate

| Environment | Monthly Cost |
|-------------|--------------|
| Production (3 VPS + managed PostgreSQL) | ~€80-150 |
| Staging (1 VPS, stopped when idle) | ~€30-50 |

## Documentation

- [Prerequisites](docs/00-prerequisites.md)
- [Infrastructure Foundation](docs/01-infrastructure-foundation.md)
- [Identity & Access](docs/02-identity-access.md)
- [Configuration Management](docs/03-configuration-management.md)
- [Monitoring](docs/04-monitoring.md)
- [Quick Reference](docs/10-quick-reference.md)

## License

MIT License - see [LICENSE](LICENSE) for details.

Third-party software attribution is documented in [OPEN_SOURCE_INVENTORY.md](OPEN_SOURCE_INVENTORY.md).
