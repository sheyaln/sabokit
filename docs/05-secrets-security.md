---
layout: default
title: "Part 5: Secrets & Security"
---

# Part 5: Secret Management & Security

Secrets are stored in Scaleway Secret Manager. Terraform creates them, you fill the value where necessary, Ansible reads them when deploying the apps.

## 5.1 Secret Flow

1. Terraform creates secret in Scaleway (terraform-scaleway-infra/secrets/ or terraform-authentik)
2. Terraform stores generated value as secret version
3. Ansible reads secret using lookup plugin
4. Ansible injects secret into .env file
5. Docker Compose reads .env and passes to container

## 5.2 Secret Types

### Database Credentials

Created by: `terraform-scaleway-infra/modules/storage/postgres/`

Naming: `postgres-{dbname}-credentials`

Content:
```json
{
  "dbname": "outline",
  "engine": "PostgreSQL-16",
  "username": "outline",
  "password": "generated-password",
  "host": "10.0.0.x",
  "port": "5432"
}
```

Usage in Ansible:
```yaml
outline_db_creds: "{% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'postgres-outline-credentials') | b64decode | from_json }}{% endraw %}"

PG_DB: "{% raw %}{{ outline_db_creds.dbname }}{% endraw %}"
PG_USER: "{% raw %}{{ outline_db_creds.username }}{% endraw %}"
PG_PASS: "{% raw %}{{ outline_db_creds.password }}{% endraw %}"
```

### OAuth Credentials

Created by: `terraform-authentik/modules/app/secrets.tf`

Naming: `authentik-app-{slug}`

Content:
```json
{
  "provider_type": "oauth2",
  "client_id": "uuid",
  "client_secret": "generated-secret",
  "scopes": "openid,profile,email",
  "redirect_uris": "https://app.example.org/callback"
}
```

Usage in Ansible:
```yaml
OIDC_CLIENT_ID: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'authentik-app-outline') | b64decode | from_json).client_id }}{% endraw %}"
OIDC_CLIENT_SECRET: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'authentik-app-outline') | b64decode | from_json).client_secret }}{% endraw %}"
```

### Application Secrets

Created by: `terraform-scaleway-infra/secrets/{app}.tf`

Naming: `{app}-secret-key`, `{app}-api-token`, etc.

Content: Plain string (base64 encoded)

Usage:
```yaml
OUTLINE_SECRET_KEY: "{% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'outline-secret-key') | b64decode }}{% endraw %}"
```

### SMTP Configuration

Secret name: `smtp-config`

Content:
```json
{
  "smtp_host": "smtp.tem.scaleway.com",
  "smtp_port": "587",
  "smtp_username": "project-id",
  "smtp_password": "api-key"
}
```

Usage in `all.yml`:
```yaml
smtp_host: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'smtp-config') | b64decode | from_json).smtp_host }}{% endraw %}"
```

## 5.3 Creating Secrets

### Via Terraform (Preferred)

In `terraform-scaleway-infra/secrets/myapp.tf`:

```hcl
locals {
  myapp_secrets = {
    "myapp-secret-key" = {
      description = "MyApp secret key"
      path        = "/apps/myapp"
      type        = "opaque"
    }
  }
}

resource "scaleway_secret" "myapp_secrets" {
  for_each    = local.myapp_secrets
  name        = each.key
  description = each.value.description
  type        = each.value.type
  path        = each.value.path
  tags        = ["myapp"]
}

# For auto-generated secrets
resource "random_password" "myapp_secret" {
  length  = 32
  special = false
}

resource "scaleway_secret_version" "myapp_secret_key" {
  secret_id = scaleway_secret.myapp_secrets["myapp-secret-key"].id
  data      = random_password.myapp_secret.result
}
```

### Via Scaleway Console

1. Go to https://console.scaleway.com
2. Navigate to Secret Manager
3. Create secret with appropriate path
4. Add version with value

### Via CLI

```bash
# Create secret
scw secret secret create name=myapp-api-key

# Create version
scw secret version create secret-id=xxx data=$(echo -n "my-secret-value" | base64)
```

## 5.4 Reading Secrets

In Ansible group_vars:

```yaml
# Simple string secret
MY_SECRET: "{% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'secret-name') | b64decode }}{% endraw %}"

# JSON secret (single field)
MY_VALUE: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'secret-name') | b64decode | from_json).field_name }}{% endraw %}"

# JSON secret (full object)
my_creds: "{% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'secret-name') | b64decode | from_json }}{% endraw %}"
```

## 5.5 Security Layers

### Cloud Level (Scaleway)

- Security groups with default deny
- Private network for internal traffic
- SSH key authentication only

### Server Level (Ansible)

- UFW firewall
- Fail2ban for brute force protection
- Unattended security updates

### Application Level

- Traefik with Let's Encrypt
- Docker socket proxy (no direct socket access)
- Container resource limits
- no-new-privileges security option

### Identity Level (Authentik)

- Centralized authentication
- Group-based access control
- Session management
- MFA support

## 5.6 Firewall Rules

### UFW (Server Level)

Configured by `roles/core/ufw/`:

```yaml
# Default policies
ufw_default_incoming: deny
ufw_default_outgoing: allow

# Always allowed
- port: 22 (SSH)
- port: 80 (HTTP)
- port: 443 (HTTPS)

# Monitoring (from management only)
- port: 9100 (Node Exporter)
- port: 8080 (cAdvisor)
```

### Security Groups (Cloud Level)

In `terraform-scaleway-infra/compute-groups.tf`:

Same ports as UFW plus Wazuh ports (1514, 1515).

## 5.7 Fail2ban

Configured by `roles/core/fail2ban/`.

Jails:
- sshd
- traefik-auth
- traefik-ratelimit
- traefik-botsearch

Check banned IPs:
```bash
sudo fail2ban-client status traefik-auth
```

Unban IP:
```bash
sudo fail2ban-client set traefik-auth unbanip 1.2.3.4
```

## 5.8 Wazuh (Security Monitoring)

Wazuh Manager runs on tools-prod.
Wazuh Agents run on all servers.

Features:
- File integrity monitoring
- Log analysis
- Vulnerability detection
- Rootkit detection

Dashboard: https://wazuh.example.cc

## 5.9 Secret Rotation

For auto-generated secrets:
1. Update Terraform to regenerate
2. Run `terraform apply`
3. Redeploy affected applications

For manual secrets (SMTP, OAuth providers):
1. Update value in Scaleway Console or CLI
2. Redeploy affected applications

Redeploy:
```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags outline
```

## 5.10 Security Checklist

Server setup:
- [ ] SSH key-only authentication
- [ ] UFW enabled with restrictive rules
- [ ] Fail2ban running
- [ ] Unattended upgrades configured
- [ ] Wazuh agent installed

Application deployment:
- [ ] Secrets from Secret Manager (not hardcoded)
- [ ] .env files have 0600 permissions
- [ ] Container has resource limits
- [ ] no-new-privileges enabled
- [ ] Traefik TLS configured

Network:
- [ ] Internal services on private network
- [ ] Public services behind Traefik
- [ ] Security groups configured
