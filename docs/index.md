---
layout: default
title: Home
---

# Federated Commons

Open-source infrastructure for unions and worker-led organizations.

This documentation provides a complete guide for deploying and managing your own self-hosted infrastructure. The stack includes:

- **Scaleway** - Cloud provider (VPS, managed PostgreSQL, S3, DNS)
- **Terraform** - Infrastructure as code
- **Ansible** - Configuration management  
- **Docker** - Container runtime
- **Authentik** - Single Sign-On and identity management
- **Traefik** - Reverse proxy with automatic SSL
- **Grafana/Prometheus/Loki** - Monitoring and observability

## Who This Is For

- Union branches wanting to deploy their own digital infrastructure
- Worker-led organizations needing secure, self-hosted tools
- Nonprofits looking for an alternative to corporate SaaS
- Anyone who wants to learn how to run a complete infrastructure stack

## Prerequisites

You should be comfortable with:

- Command line interface (terminal)
- Basic networking concepts (IP addresses, DNS, ports)

Experience with Terraform, Ansible, and Docker preferred, but not required to start - these are explained throughout, with links to thorough documentation.

## Documentation

| Section | Description |
|---------|-------------|
| [Part 0: Prerequisites](00-prerequisites) | Tools installation, environment setup |
| [Part 1: Infrastructure Foundation](01-infrastructure-foundation) | Terraform, Scaleway resources |
| [Part 2: Identity & Access](02-identity-access) | Authentik SSO, OAuth2/OIDC |
| [Part 3: Configuration Management](03-configuration-management) | Ansible playbooks and roles |
| [Part 4: Monitoring](04-monitoring) | Grafana, Prometheus, Loki, Zabbix |
| [Part 5: Secrets & Security](05-secrets-security) | Secret management, firewalls |
| [Part 6: Common Operations](06-common-operations) | Day-to-day administration |
| [Part 7: Disaster Recovery](07-disaster-recovery) | Backup and recovery |
| [Part 8: Troubleshooting](08-troubleshooting) | Common problems and solutions |
| [Part 9: Architecture](09-architecture) | System diagrams |
| [Part 10: Quick Reference](10-quick-reference) | Cheat sheets and tables |

## Quick Links

**New here?** -> Start with [Part 0: Prerequisites](00-prerequisites)

**Need to deploy something?** -> [Part 6: Common Operations](06-common-operations)

**Something broken?** -> [Part 8: Troubleshooting](08-troubleshooting)

**Quick command reference?** -> [Part 10: Quick Reference](10-quick-reference)

## Infrastructure Overview

The infrastructure consists of three servers:

| Server | Role |
|--------|------|
| `tools-prod` | Production applications (wiki, file sharing, CRM, etc.) |
| `management` | Monitoring, automation, dashboards |
| `authentik-prod` | Single Sign-On / Identity provider |

Plus managed services:

- PostgreSQL database (shared across applications)
- S3 object storage (backups, app data, Terraform state)
- DNS management

## About This Project

This infrastructure is designed to be reusable. IWW branches, worker cooperatives, unions, and nonprofits can deploy their own instance with their own domain, users, and applications while following the same patterns.

The goal is to give worker-led organizations the same quality of digital infrastructure that corporations have, without depending on corporate platforms.

---

*This documentation is open source. [View on GitHub](https://github.com/sheyaln/sabokit)*
