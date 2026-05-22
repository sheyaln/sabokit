---
layout: default
title: "Part 6: Common Operations"
---

# Part 6: Common Operations

Day-to-day tasks for managing the infrastructure.

## 6.1 Deploying an Application Update

### Update Docker Image Version

1. Edit `group-vars/{app}.yml` or the role's `defaults/main.yml`
2. Change the image tag:
   ```yaml
   app_image_tag: "0.28.7"  # was 0.28.6
   ```
3. Deploy:
   ```bash
   ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags {app}
   ```
4. Verify:
   ```bash
   ssh tools-prod "docker ps | grep {app}"
   ssh tools-prod "docker logs {app} --tail 50"
   ```

### Force Container Rebuild

```bash
ssh tools-prod
cd /opt/{app}
docker compose down
docker compose pull
docker compose up -d
```

## 6.2 Checking Application Status

### Container Status

```bash
ssh tools-prod "docker ps"
ssh management "docker ps"
ssh authentik-prod "docker ps"
```

### Application Logs

```bash
ssh tools-prod "docker logs outline --tail 100"
ssh tools-prod "docker logs outline -f"  # Follow
```

### Health Check

```bash
curl -I https://wiki.example.org
curl -I https://gateway.example.org
```

## 6.3 Restarting Services

### Single Container

```bash
ssh tools-prod "docker restart outline"
```

### Full Application Stack

```bash
ssh tools-prod
cd /opt/outline
docker compose down
docker compose up -d
```

### Traefik (Careful)

```bash
ssh tools-prod
cd /opt/traefik
docker compose restart traefik
```

Note: Restarting Traefik affects all applications temporarily.

## 6.4 Checking Server Resources

### Disk Space

```bash
ssh tools-prod "df -h"
```

### Memory

```bash
ssh tools-prod "free -h"
```

### CPU

```bash
ssh tools-prod "top -bn1 | head -20"
```

### Docker Disk Usage

```bash
ssh tools-prod "docker system df"
```

### Clean Docker

```bash
ssh tools-prod "docker system prune -af --volumes"
```

Use with caution. Removes all unused images, containers, and volumes.

## 6.5 Activating a New User

All new users are created as **inactive** by default, whether they:
- Sign up via Google or Apple (social login)
- Sign up via manual enrollment (email/password)

A delegate or admin must activate them before they can access applications.

1. Go to https://gateway.example.org/if/admin/
2. Directory > Users
3. Find the user (they will show "Inactive" status)
4. Click on the user
5. Toggle "Is active" to ON
6. Assign to appropriate group(s). (`union-member` is assigned by default)
7. Save

The user can now log in.

## 6.6 Adding a New User (Manually)

Invite via email:
1. Directory > Users > Create
2. Check "Send invite"
3. User receives email with setup link

## 6.7 Assigning User to a new Group

1. Go to https://gateway.example.org/if/admin/
2. Directory > Users > Select user
3. Groups tab > Add/Remove groups
4. Save

## 6.8 Adding a New Application

Full process:

### 1. Create DNS Record

In `terraform-scaleway-infra/dns.tf`:
```hcl
resource "scaleway_domain_record" "myapp" {
  dns_zone = scaleway_domain_zone.your_domain.id
  name     = "myapp"
  type     = "A"
  data     = module.tools_prod.public_ip  # Your tools-prod IP
  ttl      = 3600
}
```

```bash
cd terraform-scaleway-infra
terraform apply
```

### 2. Create Secrets

In `terraform-scaleway-infra/secrets/myapp.tf`:
```hcl
# Create necessary secrets
```

```bash
terraform apply
```

### 3. Create Authentik Application

In `terraform-authentik/apps.tf`:
```hcl
module "myapp" {
  source = "./modules/app"
  # ...
}
```

```bash
cd terraform-authentik
terraform apply
```

### 4. Create Ansible Role

```bash
cd ansible-vps
mkdir -p roles/tools/myapp/{tasks,templates}
```

Create tasks/main.yml, templates/docker-compose.yml.j2, templates/env.j2

### 5. Create Group Vars

Create `group-vars/myapp.yml` with database credentials, OAuth config, etc.

### 6. Add to Playbook

In `playbook-tools-prod.yml`:
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

### 7. Deploy

```bash
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags myapp
```

### 8. Verify

```bash
curl -I https://myapp.example.org
ssh tools-prod "docker logs myapp --tail 20"
```

## 6.9 Database Operations

### Connect to PostgreSQL

```bash
# Get credentials
ansible localhost -m debug -a "msg={% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'postgres-outline-credentials') | b64decode }}{% endraw %}"

# Connect via psql (from any server on private network)
ssh tools-prod
docker run -it --rm postgres:16 psql "postgresql://outline:PASSWORD@10.0.0.x:5432/outline"
```

### Backup Database

Managed PostgreSQL has automatic backups. For manual backup:

```bash
ssh tools-prod
docker run --rm postgres:16 pg_dump "postgresql://outline:PASSWORD@10.0.0.x:5432/outline" > outline_backup.sql
```

### Restore Database

```bash
ssh tools-prod
cat outline_backup.sql | docker run -i postgres:16 psql "postgresql://outline:PASSWORD@10.0.0.x:5432/outline"
```

## 6.10 SSL Certificate Issues

### Check Certificate

```bash
echo | openssl s_client -servername wiki.example.org -connect wiki.example.org:443 2>/dev/null | openssl x509 -noout -dates
```

### Force Certificate Renewal

Traefik handles this automatically. If needed:

```bash
ssh tools-prod
cd /opt/traefik
# Remove ACME storage (certificates will regenerate)
docker compose down
docker volume rm traefik_traefik_data
docker compose up -d
```

Warning: Let's Encrypt has rate limits. Don't do this frequently.

## 6.11 Viewing Logs

### Traefik Access Logs

```bash
ssh tools-prod "docker logs traefik --tail 100"
```

### Application Logs in Grafana

1. Go to https://grafana.example.cc
2. Explore > Loki
3. Query: `{container="outline"}`

### System Logs

```bash
ssh tools-prod "journalctl -u docker -n 100"
```

## 6.12 Updating Infrastructure

### Terraform Changes

```bash
cd terraform-scaleway-infra
terraform plan  # Review changes
terraform apply
```

### Ansible Changes

```bash
cd ansible-vps
ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags {tag}
```

## 6.13 Emergency Procedures

### Application Down

1. Check container: `docker ps`
2. Check logs: `docker logs {container} --tail 100`
3. Restart: `docker restart {container}`
4. If still down, check disk space and memory

### Server Unresponsive

1. Try SSH
2. If SSH fails, use Scaleway console (emergency console)
3. Check if server is running in Scaleway dashboard
4. If needed, reboot from Scaleway dashboard

### Authentik Down

Critical: all logins fail.

1. SSH to authentik-prod
2. `docker ps` - check if containers running
3. `docker logs authentik-server --tail 100`
4. Restart: `cd /opt/authentik && docker compose restart`
5. If database issue, check PostgreSQL

## 6.14 Wobbler (Script Server)

URL: https://wobbler.example.cc

Runs automation scripts via web interface.

Available scripts:
- Database backup
- Docker cleanup
- Snapshot management

SSH into target servers using dedicated key stored in Scaleway secrets.
